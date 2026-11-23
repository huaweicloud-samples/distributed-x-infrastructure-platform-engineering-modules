# =============================================================================
# worker-function-svc
# 模块能力：DMS Kafka 队列 + FunctionGraph 消费函数
# 资源构成：DMS Kafka 实例 / Topic + FunctionGraph 函数 + DMS 触发器 + 委托
# 实现说明：
#   - 死信队列由独立 Kafka Topic 承载（业务约定 + 监控告警）
#   - 消息触发由 FunctionGraph 的 DMS Kafka 触发器承担
#   - SMN 订阅投递由业务代码订阅 SMN 主题后写入 Kafka
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

# -----------------------------------------------------------------------------
# 变量
# -----------------------------------------------------------------------------

variable "region" {
  type    = string
  default = "cn-north-4"
}

variable "project_name" {
  type    = string
  default = "worker-function-svc"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "function_code_url" {
  type        = string
  description = "FunctionGraph 函数代码包 OBS URL"
}

variable "function_handler" {
  type    = string
  default = "index.handler"
}

variable "function_runtime" {
  type    = string
  default = "Python3.10"
}

variable "function_memory_mb" {
  type    = number
  default = 512
}

variable "function_timeout_s" {
  type    = number
  default = 60
}

variable "kafka_broker_num" {
  type    = number
  default = 3
}

variable "kafka_storage_size" {
  type    = number
  default = 300
}

variable "kafka_flavor_id" {
  type    = string
  default = "c6.2u4g.cluster"
}

variable "ping_topic_urn" {
  type    = string
  default = ""
}

variable "kafka_topic_partitions" {
  type    = number
  default = 3
}

variable "kafka_topic_replicas" {
  type    = number
  default = 3
}

variable "kafka_batch_size" {
  type        = number
  default     = 100
  description = "函数每次从主题消费的消息条数，取值 1–1000"
}

locals {
  processing_topic = "${var.project_name}-processing"
  dlq_topic        = "${var.project_name}-dlq"
  consumer_group   = "${var.project_name}-consumer"
}

# -----------------------------------------------------------------------------
# IAM 委托（FunctionGraph 访问 DMS Kafka）
# -----------------------------------------------------------------------------

resource "huaweicloud_identity_agency" "fgs" {
  name        = "${var.project_name}-fgs-agency"
  description = "Agency for FunctionGraph to consume DMS Kafka"
  duration    = "FOREVER"
  # 云服务委托对象：FunctionGraph 服务主体。服务主体必须写在 delegated_service_name
  # （与 delegated_domain_name 互斥），写在 domain 上会造成持续 diff
  delegated_service_name = "op_svc_cff"

  project_role {
    project = var.region
    roles = [
      "DMS Administrator",
      "SMN Administrator",
    ]
  }
}

# -----------------------------------------------------------------------------
# DMS Kafka 实例
# -----------------------------------------------------------------------------

resource "huaweicloud_dms_kafka_instance" "this" {
  name              = "${var.project_name}-kafka"
  engine_version    = "2.7"
  storage_spec_code = "dms.physical.storage.high"
  flavor_id         = var.kafka_flavor_id
  broker_num        = var.kafka_broker_num
  storage_space     = var.kafka_storage_size
  vpc_id            = var.vpc_id
  network_id        = var.subnet_id
  security_group_id = var.security_group_id
  available_zones   = ["${var.region}a", "${var.region}b", "${var.region}c"]

  tags = {
    project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# DMS Kafka 主题
# 处理主题承载正常消息；死信主题承载业务侧显式投递的失败消息
# -----------------------------------------------------------------------------

resource "huaweicloud_dms_kafka_topic" "processing" {
  instance_id = huaweicloud_dms_kafka_instance.this.id
  name        = local.processing_topic
  partitions  = var.kafka_topic_partitions
  replicas    = var.kafka_topic_replicas
}

resource "huaweicloud_dms_kafka_topic" "dlq" {
  instance_id = huaweicloud_dms_kafka_instance.this.id
  name        = local.dlq_topic
  partitions  = var.kafka_topic_partitions
  replicas    = var.kafka_topic_replicas
}

# -----------------------------------------------------------------------------
# FunctionGraph 函数（消费者）
# -----------------------------------------------------------------------------

resource "huaweicloud_fgs_function" "this" {
  name        = "${var.project_name}-function"
  agency      = huaweicloud_identity_agency.fgs.name
  handler     = var.function_handler
  memory_size = var.function_memory_mb
  timeout     = var.function_timeout_s
  runtime     = var.function_runtime

  # 函数所属应用分组（app 名）：需以字母开头，仅允许字母、数字与下划线
  app = "default"

  # 函数需与 Kafka 实例同处一个 VPC，才能经内网消费主题
  vpc_id     = var.vpc_id
  network_id = var.subnet_id

  code_type = "obs"
  code_url  = var.function_code_url

  user_data = jsonencode({
    KAFKA_BROKERS  = huaweicloud_dms_kafka_instance.this.connect_address
    TOPIC          = local.processing_topic
    DLQ_TOPIC      = local.dlq_topic
    CONSUMER_GROUP = local.consumer_group
    PING_TOPIC     = var.ping_topic_urn
  })
}

# -----------------------------------------------------------------------------
# DMS Kafka 触发器：主题消息即为函数调用事件
# 前置条件：函数须开启 VPC 访问（vpc_id / network_id），且 Kafka 所在安全组
#           放行 9092 端口入站
# 注：provider 已将本资源标记为废弃，后续可统一改为函数触发器的新资源
# -----------------------------------------------------------------------------

resource "huaweicloud_fgs_trigger" "kafka" {
  function_urn = huaweicloud_fgs_function.this.urn
  type         = "KAFKA"
  status       = "ACTIVE"

  kafka {
    instance_id = huaweicloud_dms_kafka_instance.this.id
    topic_ids   = [huaweicloud_dms_kafka_topic.processing.id]
    batch_size  = var.kafka_batch_size
  }
}

# -----------------------------------------------------------------------------
# 输出
# -----------------------------------------------------------------------------

output "function_urn" {
  value = huaweicloud_fgs_function.this.urn
}

output "kafka_instance_id" {
  value = huaweicloud_dms_kafka_instance.this.id
}

output "kafka_brokers" {
  value = huaweicloud_dms_kafka_instance.this.connect_address
}

output "kafka_topic_names" {
  description = "处理主题与死信主题名称"
  value = {
    processing = huaweicloud_dms_kafka_topic.processing.name
    dlq        = huaweicloud_dms_kafka_topic.dlq.name
  }
}
