# ProveoComercio Terraform

Infraestructura AWS para la aplicacion en ECS Fargate.

## Componentes

- VPC con subredes publicas y privadas.
- NAT Gateway para tareas privadas.
- ALB publico para frontend.
- ALB interno para backend.
- ECS Fargate para frontend, backend y worker.
- ECR para imagenes frontend, backend y migrador.
- RDS MySQL privado para usuarios, productos, stock, pedidos y folios.
- SQS + DLQ para procesamiento asincrono.
- CloudWatch Logs.

## Requisitos

Configura credenciales AWS antes de ejecutar Terraform:

```powershell
aws sts get-caller-identity --region us-east-1
```

No subas `terraform.tfvars`, `*.auto.tfvars.json`, `*.tfstate*` ni llaves `*.pem`.

## Despliegue de aplicacion

El despliegue de contenedores a ECS lo realiza el pipeline del proyecto de software en `../App/.github/workflows/cd.yml`.

El flujo es:

1. Pruebas unitarias.
2. SAST/SCA.
3. DAST.
4. Build y escaneo de imagenes.
5. Entrega continua a ECR.
6. Despliegue continuo en servicios ECS.

## Secretos

Terraform crea secretos de runtime en AWS Secrets Manager y ECS los consume desde la task definition:

- `DB_USER`
- `DB_PASSWORD`
- `JWT_SECRET`
- `SMTP_USER`
- `SMTP_PASSWORD`

Si `jwt_secret` queda vacio, Terraform genera un valor aleatorio y lo guarda en Secrets Manager. Las credenciales de AWS para ejecutar GitHub Actions no se crean desde Terraform: agregalas manualmente en GitHub Secrets para no dejarlas dentro del state de Terraform.

Despues de `terraform apply`, usa este output para ver los valores no sensibles que usa el workflow CD:

```powershell
terraform output github_actions_secret_values
```

Los secretos manuales que debes crear en GitHub son:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
AWS_REGION
```

Si usas un rol ECS existente como `LabRole`, ese rol debe poder leer secretos con `secretsmanager:GetSecretValue`.

## Pipeline CI/CD de Terraform

`Terraform CI - Pipeline Central` (`.github/workflows/terraform-ci.yml`) corre en cada push y pull request:

1. **Analisis** (`tflint-checkov.yaml`): TFLint con el plugin de AWS, despues Checkov.
2. **Validacion** (`validate.yaml`): `terraform fmt`, `terraform init -backend=false`, `terraform validate`.
3. **Despliegue** (`deploy.yaml`): solo en push directo a `main`. Genera las variables desde GitHub Secrets, y corre `terraform plan` + `terraform apply -auto-approve`. No corre en pull requests ni en `release/pipeline`, ahi solo se analiza y valida.

### Bootstrap: bucket S3 para el remote state

El pipeline necesita que el state ya viva en S3 (asi el `terraform plan` de cada corrida ve el estado real de la infraestructura, no arranca de cero). Ese bucket se crea **una sola vez, a mano**, antes del primer push:

```powershell
cd Terraform/bootstrap
terraform init
terraform apply
```

El nombre del bucket queda fijo en `Terraform/bootstrap/variables.tf` (`state_bucket_name`) y tiene que coincidir con el que usa `Terraform/providers.tf` (`backend "s3" { bucket = "..." }`). Si cambias uno, cambia el otro.

### GitHub Secrets para el despliegue automatico

Ademas de `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` y `AWS_REGION` (mismos que usa el CD de `App/`), el job de despliegue necesita:

```text
DB_USERNAME
DB_PASSWORD
SMTP_USER
SMTP_PASSWORD
MAIL_FROM
```

`AWS_SESSION_TOKEN` es un token de sesion de AWS Academy Learner Lab: vence cada pocas horas. Si el pipeline falla en el paso de `Configure AWS credentials` o en `terraform plan` con un error de autenticacion, hay que refrescar ese secret con las credenciales vigentes del lab antes de reintentar.

## Solo Infraestructura

Desde `Terraform/`:

```powershell
terraform init
terraform plan
terraform apply
```

Para crear solo ECR antes de subir imagenes:

```powershell
terraform apply "-target=module.ecr"
```

## Outputs Utiles

```powershell
terraform output frontend_url
terraform output backend_internal_alb_dns_name
terraform output db_endpoint
terraform output sqs_queue_url
terraform output ecs_cluster_name
terraform output frontend_service_name
terraform output backend_service_name
terraform output worker_service_name
```

## RDS y Stock

RDS queda privado. El backend crea tablas al arrancar si no existen. La tabla `products` contiene catalogo y stock; el descuento se hace en el backend con transacciones MySQL.

## Migracion MySQL

La imagen de migracion vive en `../App/migration`.

```powershell
$region = "us-east-1"
$migratorRepo = terraform output -raw db_migrator_ecr_repository_url
$registry = ($migratorRepo -split "/")[0]

aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry
docker build -t "$migratorRepo`:latest" ../App/migration
docker push "$migratorRepo`:latest"

terraform apply "-target=module.migration"
```

Luego ejecuta la task de migracion dentro de subredes privadas usando los outputs `migration_cluster_name`, `migration_task_definition_arn`, `private_subnet_ids` y `migration_sg_id`.
