# =============================================================================
# scheduled-function-svc
# 模块能力：FunctionGraph 定时任务（VPC 内运行）
# 资源构成：FunctionGraph 函数（含 VPC 网络配置）+ TIMER 触发器
# 实现说明：函数在指定 VPC / 子网内运行，出入向由安全组控制
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    huaweicloud = { source = "huaweicloud/huaweicloud", version = "~> 1.70" }
  }
}

provider "huaweicloud" { region = var.region }

variable "region" {
  type    = string
  default = "cn-north-4"
}
variable "project_name" {
  type    = string
  default = "scheduled-function-svc"
}
variable "function_code_url" { type = string }
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
variable "cron_expression" {
  type    = string
  default = "0 */6 * * * ?"
}
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "ping_topic_urn" {
  type    = string
  default = ""
}
resource "huaweicloud_identity_agency" "fgs" {
  name        = "${var.project_name}-fgs-agency"
  description = "Agency for scheduled FunctionGraph with VPC"
  duration    = "FOREVER"
  # 云服务委托对象：FunctionGraph 服务主体。服务主体必须写在 delegated_service_name
  # （与 delegated_domain_name 互斥），写在 domain 上会造成持续 diff
  delegated_service_name = "op_svc_cff"

  project_role {
    project = var.region
    roles   = ["SMN Administrator", "VPC Administrator", "OBS OperateAccess"]
  }
}

resource "huaweicloud_fgs_function" "this" {
  name        = "${var.project_name}-function"
  agency      = huaweicloud_identity_agency.fgs.name
  handler     = var.function_handler
  memory_size = var.function_memory_mb
  timeout     = var.function_timeout_s
  runtime     = var.function_runtime

  # 函数所属应用分组（app 名）：需以字母开头，仅允许字母、数字与下划线
  app = "default"

  code_type = "obs"
  code_url  = var.function_code_url

  # VPC 接入：FunctionGraph 只接受单个子网，取列表首个
  vpc_id     = var.vpc_id
  network_id = var.subnet_ids[0]

  user_data = jsonencode({
    PING_TOPIC_URN = var.ping_topic_urn
  })
}

resource "huaweicloud_fgs_trigger" "schedule" {
  function_urn = huaweicloud_fgs_function.this.urn
  type         = "TIMER"

  timer {
    name          = "${var.project_name}-schedule"
    schedule_type = "Cron"
    schedule      = var.cron_expression
  }
}

output "function_urn" { value = huaweicloud_fgs_function.this.urn }
output "trigger_id" { value = huaweicloud_fgs_trigger.schedule.id }
