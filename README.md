# ProveoComercio - Infraestructura (Terraform)

Este repositorio define, con Terraform, toda la infraestructura AWS donde corre ProveoComercio. Es independiente del repositorio de la aplicacion (`App`). Terraform crea el "esqueleto" (red, balanceadores, base de datos, cola, cluster ECS, repositorios de imagenes); el contenido real (las imagenes de los contenedores) lo publica el pipeline de `App`.

## Arquitectura

```text
Usuario -> ALB publico -> Frontend (Nginx, ECS Fargate)
                               |
                               v
                        ALB interno -> Backend (Node/Express, ECS Fargate) -> RDS MySQL privado
                               |
                               v
                              SQS -> Worker (ECS Fargate) -> boleta + correo (SMTP)
```

El frontend nunca habla directo con el backend por internet: el ALB publico solo conoce al frontend, y el frontend hace de proxy hacia un segundo ALB interno (sin salida a internet) que es el unico camino hacia el backend. El backend y el worker no son alcanzables desde afuera de la VPC bajo ninguna circunstancia.

## Estructura de carpetas

- `main.tf`: conecta todos los modulos entre si.
- `variables.tf`: variables de entrada del proyecto raiz.
- `outputs.tf`: valores utiles despues de aplicar (URLs, nombres de recursos, ARNs).
- `providers.tf`: version de Terraform, providers, y backend remoto (S3).
- `secrets.tf`: crea los secretos de runtime en AWS Secrets Manager.
- `terraform.tfvars.example`: plantilla de variables. `terraform.tfvars` (real, con datos propios) no se sube al repositorio.
- `modules/network`: VPC, subredes publicas y privadas, Internet Gateway, NAT Gateway(s), tablas de ruteo.
- `modules/security`: todos los Security Groups y sus reglas.
- `modules/alb`: ALB publico (frontend) y ALB interno (backend), target groups.
- `modules/database`: RDS MySQL.
- `modules/backup`: AWS Backup para respaldos diarios cifrados de RDS.
- `modules/ecr`: repositorios de imagenes (frontend, backend, migrador de base de datos).
- `modules/sqs`: cola principal y dead letter queue (DLQ).
- `modules/ecs`: cluster ECS, task definitions, servicios, autoscaling, alarmas de CloudWatch.
- `modules/migration`: task ECS temporal para importar un dump MySQL.
- `bootstrap/`: proyecto Terraform separado que crea el bucket S3 del remote state. Se aplica una sola vez, a mano.

Los modulos `ami`, `keypair`, `launch_template`, `autoscaling` y `compute` que existieron en versiones anteriores de este proyecto (pensados para una arquitectura con EC2 en vez de Fargate) fueron eliminados: no los referencia ningun `.tf` y no forman parte de la arquitectura actual.

## Modulos, en detalle

**network**
Una VPC con subredes publicas y privadas en dos zonas de disponibilidad (configurable via `subnets_config`). Internet Gateway para las subredes publicas. Uno o mas NAT Gateway para que las tareas en subredes privadas (backend, worker, RDS) tengan salida a internet sin ser alcanzables desde afuera. El default security group de la VPC queda bloqueado (sin reglas), como buena practica.

**security**
Un Security Group por cada componente: ALB publico, ALB interno, tareas frontend, tareas backend, tareas worker, RDS, y uno temporal para clientes de migracion. Todas las reglas de acceso van SG-a-SG (por referencia, no por CIDR) excepto la entrada publica del ALB en el puerto 80 y la salida HTTPS generica de las tareas privadas.

**alb**
Dos Application Load Balancer. El publico recibe trafico de internet en el puerto 80 y lo manda al frontend. El interno es privado (`internal = true`), solo alcanzable desde dentro de la VPC, y solo el frontend le puede hablar; el backend queda detras de el.

**database**
Una instancia RDS MySQL, sin acceso publico (`publicly_accessible` siempre `false`, forzado por una `validation` en la variable `db_config`). Cifrado en reposo activado por defecto. Multi-AZ configurable.

**backup**
Un vault de AWS Backup para RDS, un plan diario y una seleccion explicita del ARN de la instancia MySQL. Por defecto corre todos los dias a las 05:00 UTC, conserva recovery points por 35 dias y cifra los respaldos en el vault con cifrado administrado por AWS Backup. En una cuenta normal Terraform puede crear un rol IAM dedicado para AWS Backup; en AWS Academy Learner Lab queda configurado para reutilizar `LabRole`.

**ecr**
Tres repositorios: frontend, backend, y el migrador de base de datos. Escaneo de imagenes activado al hacer push (`scan_on_push`).

**sqs**
Cola principal mas su dead letter queue. Los mensajes que fallan demasiadas veces (`max_receive_count`) terminan en la DLQ en vez de reintentarse para siempre.

**ecs**
El modulo mas grande. Crea:

- Un cluster Fargate con Container Insights activado.
- Tres task definitions (frontend, backend, worker): CPU, memoria, imagen, variables de entorno, secretos desde Secrets Manager, health check, logging a CloudWatch.
- Tres servicios ECS, cada uno con circuit breaker de despliegue y (frontend y backend) alarmas de CloudWatch que tambien disparan rollback automatico.
- Autoscaling: frontend y backend escalan por CPU; el worker escala por profundidad de la cola SQS (mensajes visibles por tarea).
- Los roles IAM de ejecucion y de tarea, o la reutilizacion de un rol existente (ver seccion AWS Academy Learner Lab).

**migration**
Un cluster y una task definition Fargate separados, pensados para correrse una sola vez a mano cuando hay que importar un dump MySQL existente dentro de la red privada (no expuesto a internet).

## Alta disponibilidad

Las siguientes decisiones existen especificamente para que la caida de una sola pieza no tumbe la aplicacion completa.

**NAT Gateway por AZ** (`nat_gateway_per_az = true` por defecto)
Cada subred privada sale a internet por el NAT Gateway de su propia zona de disponibilidad. Con `nat_gateway_per_az = false` se usa un unico NAT Gateway compartido (mas barato, pero es punto unico de falla: si esa AZ cae, todas las tareas privadas pierden salida a internet).

**RDS Multi-AZ** (`db_config.multi_az`)
Con `multi_az = true`, RDS mantiene una replica sincronica en otra zona y hace failover automatico si la instancia primaria falla. Duplica el costo de la base de datos.

**Backups diarios con AWS Backup** (`enable_backup`, `backup_config`)
Ademas de la retencion nativa de RDS (`backup_retention_period`), Terraform crea AWS Backup para tener una capa centralizada de respaldo. El plan diario guarda recovery points cifrados en un backup vault y los borra automaticamente despues de `backup_config.retention_days` dias. Esto protege contra errores de aplicacion o borrados accidentales dentro de la ventana de retencion, pero no reemplaza Multi-AZ: Multi-AZ es continuidad operativa, AWS Backup es recuperacion.

**Minimo dos tareas por servicio**
`frontend_desired_count`, `backend_desired_count` y `worker_desired_count` en 2 (configurable) para que el reinicio o la falla de una tarea no deje el servicio sin ninguna instancia corriendo.

**Circuit breaker de despliegue**
Los tres servicios ECS tienen `deployment_circuit_breaker` con `rollback = true`: si las tareas nuevas no llegan a pasar el health check despues de varios intentos, ECS revierte solo a la ultima revision estable, sin intervencion humana.

**Alarmas de CloudWatch como segunda linea de defensa**
Ademas del circuit breaker (que solo mira el health check del contenedor), frontend y backend tienen una alarma de CloudWatch sobre la tasa de errores 5xx real del ALB. Si un despliegue deja el contenedor "sano" segun su health check pero la aplicacion responde con errores bajo trafico real, esa alarma tambien dispara el rollback automatico del servicio.

**Rollback manual**
Cuando el problema no es detectable automaticamente (por ejemplo, un bug visual que no genera errores HTTP), se puede revertir un servicio especifico a una revision anterior de su task definition sin reconstruir nada, porque ECS conserva todas las revisiones anteriores y cada una apunta a una imagen fija por commit. El workflow `App/.github/workflows/rollback.yml` hace esto de forma guiada (ver ese repositorio); el equivalente manual es:

```bash
aws ecs update-service --cluster proveocomercio-cluster --service <nombre-del-servicio> --task-definition <familia>:<revision> --force-new-deployment
```

## Seguridad

- RDS es privado siempre (validado por Terraform, no es una opcion que se pueda desactivar por accidente).
- RDS tiene almacenamiento cifrado y un plan diario de AWS Backup con recovery points cifrados en un vault dedicado.
- Las credenciales de runtime (usuario y password de DB, JWT secret, usuario y password SMTP) se guardan en AWS Secrets Manager, no en variables de entorno planas ni en el codigo. ECS las inyecta en tiempo de ejecucion via el bloque `secrets` de la task definition.
- Si `jwt_secret` se deja vacio en las variables, Terraform genera un valor aleatorio y lo guarda directamente en Secrets Manager.
- El backend recibe `FRONTEND_URL` para restringir CORS a ese origen en produccion, en vez de aceptar cualquiera.

**Limitacion conocida: no hay HTTPS.** Los dos ALB solo escuchan en el puerto 80. No hay certificado ACM ni dominio propio configurado porque el entorno objetivo (AWS Academy Learner Lab) normalmente no tiene un dominio verificable disponible. Esto significa que las credenciales viajan sin cifrar entre el navegador y el ALB. Si este proyecto se usa mas alla de un entorno de practica, agregar un listener HTTPS con un certificado ACM (o un proxy como Cloudflare delante) antes de manejar datos reales de usuarios.

## Remote state (bucket S3)

El state de Terraform vive en S3, no en el disco local, para que tanto una persona corriendo Terraform desde su maquina como el pipeline de CI vean siempre el mismo estado real de la infraestructura.

El backend esta configurado en `providers.tf`:

```hcl
backend "s3" {
  bucket       = "proveocomercio-tfstate-a6fa98c1"
  key          = "proveocomercio/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
}
```

`use_lockfile` activa el locking nativo de S3 (Terraform 1.10 en adelante): evita que dos aplicaciones corran al mismo tiempo sobre el mismo state, sin necesitar una tabla DynamoDB aparte.

Ese bucket no existe solo: hay que crearlo una vez, a mano, con el proyecto separado `bootstrap/`, antes de la primera vez que se usa el backend S3 (ya sea localmente o en el pipeline):

```powershell
cd Terraform/bootstrap
terraform init
terraform apply
```

`bootstrap/` crea el bucket con versioning, cifrado del lado del servidor, bloqueo total de acceso publico, una politica que rechaza cualquier acceso que no sea HTTPS, y una regla de ciclo de vida que borra versiones viejas del state despues de 90 dias (para no acumular storage indefinidamente) y aborta cargas multipart incompletas despues de 7 dias. Su propio state queda local (`bootstrap/bootstrap.tfstate`): no puede usar el bucket que el mismo esta creando.

Si se cambia el nombre del bucket, hay que cambiarlo en dos lugares a la vez: `bootstrap/variables.tf` (`state_bucket_name`) y `providers.tf` (`backend "s3" { bucket = "..." }`).

**Por que es privado y no publico:** el archivo de state guarda en texto plano el valor real de todos los atributos de cada recurso, incluidas las contraseñas de `db_config` y `smtp_config` y el JWT secret generado. Que las variables tengan `sensitive = true` solo oculta el valor en la salida de `terraform plan`/`apply` en la terminal; no cifra ni oculta nada dentro del archivo de state en si. Un bucket publico expondria esas credenciales directamente.

## Variables de entrada

`terraform.tfvars.example` documenta todas las variables. Las mas relevantes:

- `project_name`, `aws_region`: identifican el proyecto y la region.
- `subnets_config`: mapa de subredes, con zona de disponibilidad, numero de subred, y si es publica o privada.
- `nat_gateway_per_az`: ver seccion Alta disponibilidad.
- `alb_config`: nombre, puertos y protocolo de los balanceadores.
- `db_config`: motor, version, clase de instancia, usuario, password, storage, `multi_az`, cifrado, retencion de backups, proteccion contra borrado. `publicly_accessible` siempre debe quedar en `false`.
- `enable_backup`, `backup_config`: activa AWS Backup para RDS, con schedule diario, ventana de inicio/finalizacion, retencion, KMS opcional y rol IAM de backup.
- `smtp_config`: host, puerto, usuario, password y remitente para el correo de confirmacion.
- `frontend_desired_count`, `backend_desired_count`, `worker_desired_count`, `worker_min_capacity`, `worker_max_capacity`: cantidad de tareas por servicio (ver Alta disponibilidad).
- `jwt_secret`: opcional. Si se deja vacio, Terraform genera uno.

### AWS Academy Learner Lab

Variables: `create_iam_roles`, `task_execution_role_name`, `task_role_name`, `enable_ecs_autoscaling`.

En un Learner Lab no se pueden crear roles IAM propios: solo existe un rol ya creado, `LabRole`, y hay que reutilizarlo. Con `create_iam_roles = false`, Terraform no intenta crear `aws_iam_role` ni `aws_iam_role_policy`: en su lugar arma el ARN del rol existente a partir de `task_execution_role_name` y `task_role_name` (por defecto `"LabRole"` en `terraform.tfvars.example`). Con esto activo, ese rol tiene que poder leer los secretos de Secrets Manager y usar la cola SQS por si mismo, porque Terraform tampoco le adjunta politicas propias.

`enable_ecs_autoscaling = false` desactiva la creacion de Application Auto Scaling (target tracking por CPU y por cola SQS), porque en algunos Learner Lab el rol de servicio vinculado que usa Auto Scaling tampoco se puede crear. Con autoscaling desactivado, la cantidad de tareas queda fija en `desired_count`; sigue habiendo redundancia (2 tareas por servicio) pero no escalado dinamico.

Para AWS Backup, el pipeline de Learner Lab usa `backup_config.create_iam_role = false` y `backup_config.backup_role_name = "LabRole"`. Si AWS Backup no puede asumir ese rol en tu laboratorio, crea o habilita una vez el rol `AWSBackupDefaultServiceRole` desde la consola de AWS Backup y cambia `backup_role_name` por ese nombre.

## Uso local manual

Con credenciales AWS validas ya configuradas (variables de entorno o `~/.aws/credentials`):

```powershell
cd Terraform
terraform init
terraform plan
terraform apply
```

Para crear solo el ECR antes de tener nada mas (por ejemplo, para poder empezar a subir imagenes mientras el resto de la infraestructura se sigue definiendo):

```powershell
terraform apply "-target=module.ecr"
```

### Orden recomendado la primera vez, de cero

1. `bootstrap/`: crear el bucket S3 del state (una sola vez, ver seccion Remote state).
2. `Terraform/`: `terraform init` (ahora si contra el backend S3 real) y `terraform apply`. Esto crea la red, RDS, SQS, los ECR, el cluster ECS con sus tres servicios y los ALB.
3. En este punto los servicios ECS existen pero no tienen nada corriendo: las task definitions apuntan por defecto a la etiqueta `:latest` de cada repositorio ECR, que todavia esta vacio. Es normal ver tareas fallando al intentar bajar la imagen; `terraform apply` no se cuelga ni falla por esto.
4. Correr el pipeline de `App` (push a `main`, o `workflow_dispatch` de `cd.yml`). Ese pipeline construye las imagenes reales, las sube a los ECR que ya existen, y fuerza el redeploy de los tres servicios ECS con una task definition nueva que apunta a la imagen real. Recien ahi la aplicacion queda arriba de verdad.

## Pipeline CI/CD de este repositorio

`Terraform CI - Pipeline Central` (`.github/workflows/terraform-ci.yml`) es el workflow que se dispara con cada push y pull request. Llama a tres workflows reutilizables en orden.

### 1. analisis -> tflint-checkov.yaml

TFLint con el plugin de AWS (`tflint-ruleset-aws`), configurado en `.tflint.hcl` en la raiz del repositorio. Corre en modo recursivo sobre todos los modulos, incluyendo `bootstrap/`. Dos reglas quedan desactivadas a proposito (`terraform_required_providers` y `terraform_required_version` por modulo): son modulos internos que nunca se publican ni se usan fuera de este repositorio, y el root ya fija las versiones de provider centralmente en `providers.tf`.

Despues corre Checkov. La version de codigo abierto no trae severidad (eso requiere una cuenta Bridgecrew/Prisma Cloud conectada), asi que en vez de filtrar por severidad se usa una lista explicita de checks aceptados a proposito para este proyecto (`--skip-check` en el workflow), con la razon de cada uno comentada ahi mismo. En resumen, se aceptan: falta de HTTPS (sin dominio/ACM en este entorno), cifrado con la clave gestionada por AWS en vez de una KMS CMK propia (Secrets Manager, ECR, CloudWatch Logs, AWS Backup, bucket de state), falta de rotacion automatica de secretos, falta de WAF, deletion protection apagado (entorno de practica que se recrea seguido), retencion de logs en 7 dias, tags mutables en ECR (el pipeline de CD depende de re-publicar el tag `:latest` en cada deploy), y un puñado de falsos positivos conocidos de Checkov con Security Groups y EIP referenciados entre modulos.

### 2. validacion -> validate.yaml

`terraform fmt -check`, `terraform init -backend=false`, `terraform validate`. No necesita credenciales AWS: solo revisa que la sintaxis y los tipos sean correctos.

### 3. despliegue -> deploy.yaml

Solo corre en push directo a `main` (no en pull requests, no en la rama `release/pipeline`: ahi el pipeline se queda solo en analisis y validacion). Genera un `terraform.auto.tfvars.json` en el runner combinando valores no sensibles hardcodeados directamente en `deploy.yaml` (subredes, puertos, tamaños, configuracion de Learner Lab) con los valores sensibles que vienen de GitHub Secrets (usuario y password de la base de datos, usuario, password y remitente de SMTP), armados con `jq` para que un caracter especial en un secreto no rompa el JSON. Con ese archivo corre `terraform init`, `terraform plan`, y `terraform apply -auto-approve`, sin gate de aprobacion manual.

Importante: ese `terraform.auto.tfvars.json` es una reconstruccion de `terraform.tfvars` pensada para el pipeline, no el mismo archivo. Si se cambia algo en `terraform.tfvars` local que no sea un secreto (por ejemplo la cantidad de tareas o la clase de instancia de RDS), hay que replicar ese cambio a mano en el bloque `jq` de `deploy.yaml`, porque son dos copias separadas de la misma configuracion.

## GitHub Secrets que necesita este repositorio

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`: credenciales AWS.
- `AWS_SESSION_TOKEN`: obligatorio en AWS Academy Learner Lab (la sesion vence cada pocas horas: si el pipeline falla en "Configure AWS credentials" o en `terraform plan`/`apply` con un error de autenticacion, hay que refrescar este secreto con las credenciales vigentes del lab). Puede quedar vacio en una cuenta AWS normal con credenciales permanentes.
- `DB_USERNAME`, `DB_PASSWORD`: credenciales del usuario administrador de RDS.
- `SMTP_USER`, `SMTP_PASSWORD`, `MAIL_FROM`: credenciales del proveedor SMTP usado para el correo de confirmacion de compra.

Estos secretos son propios de este repositorio (Terraform). El repositorio `App` tiene su propio conjunto de secretos (algunos coinciden, como las credenciales AWS): al ser dos repositorios de GitHub independientes, no comparten secretos entre si salvo que se configuren como Organization secrets.

## Migracion de base de datos

La imagen de migracion vive en `../App/migration`. Se construye y se sube al ECR correspondiente, y se corre la task una sola vez dentro de la red privada:

```powershell
$region = "us-east-1"
$migratorRepo = terraform output -raw db_migrator_ecr_repository_url
$registry = ($migratorRepo -split "/")[0]

aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry
docker build -t "$migratorRepo`:latest" ../App/migration
docker push "$migratorRepo`:latest"

terraform apply "-target=module.migration"
```

Despues, correr la task de migracion dentro de las subredes privadas usando los outputs `migration_cluster_name`, `migration_task_definition_arn`, `private_subnet_ids` y `migration_sg_id`.

## RDS y stock

RDS queda siempre privado. El backend crea las tablas al arrancar si no existen. La tabla `products` contiene el catalogo y el stock; el descuento de stock se hace en el backend, dentro de una transaccion MySQL con bloqueo de fila, para evitar sobreventa cuando hay pedidos simultaneos por el mismo producto.

## Outputs utiles

```powershell
terraform output frontend_url
terraform output backend_internal_alb_dns_name
terraform output db_endpoint
terraform output backup_vault_name
terraform output backup_plan_id
terraform output sqs_queue_url
terraform output ecs_cluster_name
terraform output frontend_service_name
terraform output backend_service_name
terraform output worker_service_name
terraform output nat_public_ip
terraform output github_actions_secret_values
```

## Troubleshooting

**Error "S3 bucket ... does not exist" al correr `terraform init`.**
Falta el paso de bootstrap. Ver seccion Remote state: hay que crear el bucket una vez, a mano, antes de inicializar el proyecto principal.

**El pipeline falla en "Configure AWS credentials" o en `terraform plan` con un error de autenticacion.**
El `AWS_SESSION_TOKEN` de GitHub Secrets vencio (tipico en AWS Academy Learner Lab, cada pocas horas). Hay que generar credenciales nuevas desde el panel del lab y actualizar los secretos `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` en GitHub.

**`terraform apply` crea el cluster y los servicios ECS pero las tareas no arrancan.**
Es esperado si todavia no corrio el pipeline de `App` al menos una vez: los ECR estan vacios. Ver "Orden recomendado la primera vez, de cero" mas arriba.

**`terraform plan` quiere recrear o modificar recursos que ya existen y no deberian tocarse.**
Verificar que se este usando el mismo bucket de state (y la misma key) que se uso para crear esos recursos la primera vez. Si el proyecto se aplico alguna vez con backend local y despues se migro a S3, el state local y el remoto pueden haber quedado desincronizados.
