module "network" {
  source             = "./modules/network"
  enable_network     = var.enable_network
  vpc_cidr           = var.vpc_cidr
  project_name       = var.project_name
  subnets_config     = var.subnets_config
  nat_gateway_per_az = var.nat_gateway_per_az
}

module "security" {
  source        = "./modules/security"
  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  frontend_port = var.frontend_port
  backend_port  = var.backend_port
}

module "alb" {
  source                     = "./modules/alb"
  project_name               = var.project_name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = values(module.network.public_subnet_ids)
  security_group_ids         = [module.security.alb_sg_id]
  backend_subnet_ids         = values(module.network.private_subnet_ids)
  backend_security_group_ids = [module.security.backend_alb_sg_id]
  enable_alb                 = true
  alb_config = {
    name                 = var.alb_config.name
    internal             = false
    listener_port        = 80
    protocol             = "HTTP"
    frontend_port        = var.alb_config.frontend_port
    backend_port         = var.alb_config.backend_port
    backend_path_pattern = var.alb_config.backend_path_pattern
    target_protocol      = var.alb_config.target_protocol
  }
}

module "database" {
  source            = "./modules/database"
  create_db         = var.create_db
  project_name      = var.project_name
  db_config         = var.db_config
  subnet_ids        = values(module.network.private_subnet_ids)
  security_group_id = module.security.db_sg_id
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

module "sqs" {
  source                     = "./modules/sqs"
  project_name               = var.project_name
  enable_sqs                 = true
  max_receive_count          = var.sqs_config.max_receive_count
  visibility_timeout_seconds = var.sqs_config.visibility_timeout_seconds
  message_retention_seconds  = var.sqs_config.message_retention_seconds
  delay_seconds              = var.sqs_config.delay_seconds
  receive_wait_time_seconds  = var.sqs_config.receive_wait_time_seconds
}

module "migration" {
  source                   = "./modules/migration"
  project_name             = var.project_name
  aws_region               = var.aws_region
  cluster_name             = "${var.project_name}-migration-cluster"
  migration_image          = var.db_migrator_image != "" ? var.db_migrator_image : "${module.ecr.db_migrator_repo_url}:latest"
  task_execution_role_name = var.task_execution_role_name
  task_execution_role_arn  = var.task_execution_role_arn
  task_role_name           = var.task_role_name != "" ? var.task_role_name : var.task_execution_role_name
  task_role_arn            = var.task_role_arn
  db_host                  = var.create_db ? module.database.db_endpoint : var.external_db_host
  db_port                  = var.create_db ? module.database.db_port : var.external_db_port
  db_name                  = var.db_config.name
  db_user_secret_arn       = aws_secretsmanager_secret.app["db_user"].arn
  db_password_secret_arn   = aws_secretsmanager_secret.app["db_password"].arn
}

module "ecs" {
  source                           = "./modules/ecs"
  project_name                     = var.project_name
  aws_region                       = var.aws_region
  cluster_name                     = "${var.project_name}-cluster"
  backend_upstream                 = "${module.alb.backend_internal_dns_name}:80"
  backend_resolver                 = cidrhost(var.vpc_cidr, 2)
  frontend_url                     = "http://${module.alb.alb_dns_name}"
  create_iam_roles                 = var.create_iam_roles
  task_execution_role_name         = var.task_execution_role_name
  task_execution_role_arn          = var.task_execution_role_arn
  task_role_name                   = var.task_role_name
  task_role_arn                    = var.task_role_arn
  enable_autoscaling               = var.enable_ecs_autoscaling
  frontend_image                   = var.frontend_image != "" ? var.frontend_image : "${module.ecr.frontend_repo_url}:latest"
  backend_image                    = var.backend_image != "" ? var.backend_image : "${module.ecr.backend_repo_url}:latest"
  frontend_port                    = var.frontend_port
  backend_port                     = var.backend_port
  frontend_desired_count           = var.frontend_desired_count
  backend_desired_count            = var.backend_desired_count
  cpu                              = var.ecs_cpu
  memory                           = var.ecs_memory
  subnet_ids                       = values(module.network.private_subnet_ids)
  frontend_security_group_ids      = [module.security.frontend_ecs_sg_id]
  backend_security_group_ids       = [module.security.backend_ecs_sg_id]
  worker_security_group_ids        = [module.security.worker_ecs_sg_id]
  frontend_target_group_arn        = module.alb.frontend_target_group_arn
  frontend_target_group_arn_suffix = module.alb.frontend_target_group_arn_suffix
  frontend_alb_arn_suffix          = module.alb.alb_arn_suffix
  backend_target_group_arn         = module.alb.backend_target_group_arn
  backend_target_group_arn_suffix  = module.alb.backend_target_group_arn_suffix
  backend_alb_arn_suffix           = module.alb.backend_alb_arn_suffix
  db_host                          = var.create_db ? module.database.db_endpoint : var.external_db_host
  db_port                          = var.create_db ? module.database.db_port : var.external_db_port
  db_name                          = var.db_config.name
  db_user_secret_arn               = aws_secretsmanager_secret.app["db_user"].arn
  db_password_secret_arn           = aws_secretsmanager_secret.app["db_password"].arn
  jwt_secret_arn                   = aws_secretsmanager_secret.app["jwt_secret"].arn
  smtp_host                        = var.smtp_config.host
  smtp_port                        = var.smtp_config.port
  smtp_user_secret_arn             = aws_secretsmanager_secret.app["smtp_user"].arn
  smtp_password_secret_arn         = aws_secretsmanager_secret.app["smtp_password"].arn
  smtp_secure                      = var.smtp_config.secure
  mail_from                        = var.smtp_config.mail_from
  sqs_queue_url                    = module.sqs.queue_url
  sqs_queue_arn                    = module.sqs.queue_arn
  sqs_queue_name                   = module.sqs.queue_name
  worker_desired_count             = var.worker_desired_count
  worker_min_capacity              = var.worker_min_capacity
  worker_max_capacity              = var.worker_max_capacity
  worker_queue_messages_per_task   = var.worker_queue_messages_per_task

  depends_on = [module.alb]
}
