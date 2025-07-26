locals {
  log_group_name     = "/ecs/${var.app_name}-${var.app_environment}"
  api_container_name = "${var.app_name}-${var.app_environment}-api"
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.0"
  
  ####################################
  # ECS Cluster
  ####################################
  cluster_name = "${var.app_name}-${var.app_environment}-cluster"

  ####################################
  # Log Group
  ####################################
  cloudwatch_log_group_name              = local.log_group_name
  cloudwatch_log_group_retention_in_days = 7

  ####################################
  # Services
  ####################################
  services = merge(
    {
      api_service = {
        name                   = "${var.app_name}-api-service"
        create_security_group  = false
        create_task_definition = false
        task_definition_arn    = aws_ecs_task_definition.api_task.arn
        desired_count          = 1
        platform_version       = "LATEST"
        force_new_deployment   = true
        assign_public_ip       = true
        subnet_ids             = var.public_subnets
        security_group_ids     = [var.api_security_group_id]

        autoscaling = {
          min_capacity = 1
          max_capacity = 3
          cpu = {
            target_value       = 75
            scale_in_cooldown  = 300
            scale_out_cooldown = 300
          }
        }

        load_balancer = {
          service = {
            target_group_arn = var.api_target_group_arn
            container_name   = local.api_container_name
            container_port   = 3000
          }
        }
      }
    },
    # Processing tasks for each chain
    {
      for chain in var.CHAINS : "processing_${chain.id}" => {
        name                   = "processing-${chain.id}"
        create_security_group  = false
        create_task_definition = false
        task_definition_arn    = aws_ecs_task_definition.processing_tasks[chain.id].arn
        desired_count          = 1
        platform_version       = "LATEST"
        force_new_deployment   = true
        assign_public_ip       = true
        subnet_ids             = var.public_subnets
        security_group_ids     = [var.processing_security_group_id]

        autoscaling = {
          min_capacity = 1
          max_capacity = 2
          cpu = {
            target_value       = 75
            scale_in_cooldown  = 300
            scale_out_cooldown = 300
          }
        }
      }
    }
  )

  tags = {
    Environment = var.app_environment
    Project     = var.app_name
  }
}

####################################
# Combined API + Hasura Task Definition
####################################
resource "aws_ecs_task_definition" "api_task" {
  family                   = "${var.app_name}-${var.app_environment}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 3072
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "indexer-graphql-api"
      image     = "hasura/graphql-engine:v2.43.0"
      essential = false
      
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "HASURA_GRAPHQL_DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "HASURA_GRAPHQL_ENABLE_CONSOLE"
          value = "true"
        },
        {
          name  = "HASURA_GRAPHQL_ADMIN_SECRET"
          value = "secret"
        },
        {
          name  = "HASURA_GRAPHQL_UNAUTHORIZED_ROLE"
          value = "public"
        },
        {
          name  = "HASURA_GRAPHQL_CORS_DOMAIN"
          value = "*"
        },
        {
          name  = "HASURA_GRAPHQL_ENABLE_TELEMETRY"
          value = "false"
        },
        {
          name  = "HASURA_GRAPHQL_EXPERIMENTAL_FEATURES"
          value = "bigquery_string_numeric_input,naming_convention"
        },
        {
          name  = "HASURA_GRAPHQL_DEFAULT_NAMING_CONVENTION"
          value = "graphql-default"
        },
        {
          name  = "HASURA_GRAPHQL_BIGQUERY_STRING_NUMERIC_INPUT"
          value = "true"
        },
        {
          name  = "HASURA_GRAPHQL_DEV_MODE"
          value = "true"
        },
        {
          name  = "HASURA_GRAPHQL_ENABLED_LOG_TYPES"
          value = "startup, http-log, webhook-log, websocket-log, query-log"
        },
        {
          name  = "HASURA_GRAPHQL_ADMIN_INTERNAL_ERRORS"
          value = "true"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "indexer-graphql-api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "timeout 1s bash -c ':> /dev/tcp/127.0.0.1/8080' || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = local.api_container_name
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      dependsOn = [
        {
          containerName = "indexer-graphql-api"
          condition     = "HEALTHY"
        }
      ]
      
      command = ["npm", "run", "start"]
      
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.app_environment
        },
        {
          name  = "PORT"
          value = "3000"
        },
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "REDIS_URL"
          value = var.redis_url
        },
        {
          name  = "PRICING_SOURCE"
          value = var.pricing_source
        },
        {
          name  = "COINGECKO_API_KEY"
          value = var.coingecko_api_key
        },
        {
          name  = "COINGECKO_API_TYPE"
          value = var.coingecko_api_type
        },
        {
          name  = "METADATA_SOURCE"
          value = var.metadata_source
        },
        {
          name  = "PUBLIC_GATEWAY_URLS"
          value = jsonencode(var.public_gateway_urls)
        },
        {
          name  = "LOG_LEVEL"
          value = var.log_level
        },
        {
          name  = "CHAINS"
          value = jsonencode(var.CHAINS)
        },
        {
          name  = "INDEXER_GRAPHQL_URL"
          value = var.indexer_graphql_url
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Environment = var.app_environment
    Project     = var.app_name
  }
}

####################################
# Processing Task Definitions
####################################
resource "aws_ecs_task_definition" "processing_tasks" {
  for_each                 = { for chain in var.CHAINS : chain.id => chain }
  family                   = "processing-${each.value.id}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "processing-${each.value.id}"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      
      command = ["npm", "run", "start", "--", "--chain", tostring(each.value.id)]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.app_environment
        },
        {
          name  = "DATABASE_URL"
          value = var.database_url
        },
        {
          name  = "REDIS_URL"
          value = var.redis_url
        },
        {
          name  = "CHAIN_ID"
          value = tostring(each.value.id)
        },
        {
          name  = "PRICING_SOURCE"
          value = var.pricing_source
        },
        {
          name  = "COINGECKO_API_KEY"
          value = var.coingecko_api_key
        },
        {
          name  = "COINGECKO_API_TYPE"
          value = var.coingecko_api_type
        },
        {
          name  = "METADATA_SOURCE"
          value = var.metadata_source
        },
        {
          name  = "PUBLIC_GATEWAY_URLS"
          value = jsonencode(var.public_gateway_urls)
        },
        {
          name  = "LOG_LEVEL"
          value = var.log_level
        },
        {
          name  = "INDEXER_GRAPHQL_URL"
          value = var.indexer_graphql_url
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "processing-${each.value.id}"
        }
      }
    }
  ])

  tags = {
    Environment = var.app_environment
    Project     = var.app_name
    Chain       = each.value.id
  }
}
