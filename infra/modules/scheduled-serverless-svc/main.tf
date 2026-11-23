# =============================================================================
# scheduled-serverless-svc
# 模块能力：FunctionGraph 定时触发器（无容器依赖的定时任务）
# 资源构成：FunctionGraph 函数 + TIMER 触发器 + 委托
# 实现说明：
#   - 定时表达式直接配在 FunctionGraph TIMER 触发器上
#   - 任务体即函数本身，不需要容器运行时
#   - 函数访问云服务的授权由 IAM 委托承担
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
  default = "scheduled-serverless-svc"
}
variable "function_code_url" {
  type        = string
  description = "FunctionGraph 函数代码 OBS URL"
}
variable "function_handler" {
  type    = string
  default = "index.handler"
}
variable "function_runtime" {
  type    = string
  default = "Python3.10"
}
variable "cron_expression" {
  type        = string
  default     = "0 */6 * * * ?"
  description = "标准 6 字段 cron 表达式（含秒）"
}
variable "ping_topic_urn" {
  type    = string
  default = ""
}
resource "huaweicloud_identity_agency" "fgs" {
  name        = "${var.project_name}-fgs-agency"
  description = "Agency for scheduled FunctionGraph"
  duration    = "FOREVER"
  # 云服务委托对象：FunctionGraph 服务主体。服务主体必须写在 delegated_service_name
  # （与 delegated_domain_name 互斥），写在 domain 上会造成持续 diff
  delegated_service_name = "op_svc_cff"

  project_role {
    project = var.region
    roles   = ["SMN Administrator", "OBS OperateAccess"]
  }
}

resource "huaweicloud_fgs_function" "this" {
  name        = "${var.project_name}-function"
  agency      = huaweicloud_identity_agency.fgs.name
  handler     = var.function_handler
  memory_size = 512
  timeout     = 300
  runtime     = var.function_runtime

  # 函数所属应用分组（app 名）：需以字母开头，仅允许字母、数字与下划线
  app = "default"

  code_type = "obs"
  code_url  = var.function_code_url

  user_data = jsonencode({
    PING_TOPIC_URN = var.ping_topic_urn
  })
}

# 定时触发器
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
