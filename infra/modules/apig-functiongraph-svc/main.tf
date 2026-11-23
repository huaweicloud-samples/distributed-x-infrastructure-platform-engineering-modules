# =============================================================================
# apig-functiongraph-svc
# 模块能力：APIG 专享版（API 网关）+ FunctionGraph（函数计算）对外提供 HTTP API
# 资源构成：
#   - APIG 专享版实例 / 分组 / 环境 / API 与发布
#     （huaweicloud_apig_instance / apig_group / apig_environment / apig_api / apig_api_publishment）
#   - FunctionGraph 函数（huaweicloud_fgs_function）
#   - LTS 日志组 / 日志流（huaweicloud_lts_group / lts_stream）
#   - FunctionGraph 委托（huaweicloud_identity_agency）——函数访问 SMN / OBS 的授权载体
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
  default = "apig-functiongraph-svc"
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
  description = "FunctionGraph 函数代码包 OBS URL（zip 格式）"
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
  default = 30
}

variable "ping_topic_urn" {
  type        = string
  description = "来自环境模块（用于向 SMN 发布 ping）"
}

variable "environment_name" {
  type        = string
  default     = "RELEASE"
  description = "API 发布环境名称；API 须发布到环境后才会产生可调用的对外入口"
}

# -----------------------------------------------------------------------------
# IAM 委托（让 FunctionGraph 可访问 SMN）
# -----------------------------------------------------------------------------

resource "huaweicloud_identity_agency" "fgs" {
  name        = "${var.project_name}-fgs-agency"
  description = "Agency for FunctionGraph to access SMN"
  duration    = "FOREVER"
  # 云服务委托对象：FunctionGraph 服务主体。服务主体必须写在 delegated_service_name
  # （与 delegated_domain_name 互斥），写在 domain 上会造成持续 diff
  delegated_service_name = "op_svc_cff"

  project_role {
    project = var.region
    roles = [
      "SMN Administrator",
      "OBS OperateAccess",
    ]
  }
}

# -----------------------------------------------------------------------------
# LTS 日志流
# -----------------------------------------------------------------------------

resource "huaweicloud_lts_group" "this" {
  group_name  = "${var.project_name}-lts"
  ttl_in_days = 30
}

resource "huaweicloud_lts_stream" "this" {
  group_id    = huaweicloud_lts_group.this.id
  stream_name = "${var.project_name}-api"
  ttl_in_days = 30
}

# -----------------------------------------------------------------------------
# APIG 专享实例
# -----------------------------------------------------------------------------

# 专享实例需要显式指定可用区，缺省时云端会拒绝创建
data "huaweicloud_availability_zones" "this" {}

resource "huaweicloud_apig_instance" "this" {
  name               = "${var.project_name}-apig"
  edition            = "BASIC"
  vpc_id             = var.vpc_id
  subnet_id          = var.subnet_id
  security_group_id  = var.security_group_id
  maintain_begin     = "02:00:00"
  availability_zones = [data.huaweicloud_availability_zones.this.names[0]]

  # 公网入口（D9/D10 修复）：本实例为 ELB 类型（loadbalancer_provider="elb"），
  # 仅支持 ELB 入公网机制（POST /ingress-eip），不能走 LVS 专用的 eip_id 绑定
  # （ELB 类型实例不支持 eip_id 绑定，会报 APIC.7242）。
  # 入公网 EIP 由 APIG 系统托管创建，采用固定带宽接入（bandwidth_charging_mode="bandwidth"）。
  # 注意：该实例/账户不支持按流量接入（APIC.7259），此处采用 "bandwidth" 带宽类型
  # 两种方式均由 APIG 托管，无需单独管理 EIP 资源；ingress_bandwidth_size
  # 为入公网带宽（最小值 5 Mbps）。
  ingress_bandwidth_size          = 5
  ingress_bandwidth_charging_mode = "bandwidth"

  # 出公网（NAT）带宽置 0 = 关闭出公网访问（本场景仅需入公网）。
  bandwidth_size = 0

  tags = {
    project = var.project_name
  }
}

# -----------------------------------------------------------------------------
# 公网入口的 EIP 由 APIG 入公网机制（ingress-eip）系统托管创建，
# 带宽接入方式由 ingress_bandwidth_charging_mode="bandwidth" 决定。
# 因此无需（也不能）再单独创建 huaweicloud_vpc_eip 并通过 eip_id 绑定——
# eip_id 绑定仅适用于 LVS 类型实例（ELB 实例会报 APIC.7242）。
# -----------------------------------------------------------------------------

# DEFAULT 分组为实例预置分组：使用裸 IP（入公网 EIP）调用 API 时，仅 DEFAULT 分组免绑定
# 入口 IP；非 DEFAULT 分组需到控制台手动把入口 IP 与分组绑定（Terraform provider 无该属性，
# 非 DEFAULT 分组需手动绑定入口 IP），否则裸 IP 调用报 APIG.0101。故本模块将 API 置于 DEFAULT 分组。
data "huaweicloud_apig_groups" "default" {
  instance_id = huaweicloud_apig_instance.this.id
  name        = "DEFAULT"
}

# -----------------------------------------------------------------------------
# FunctionGraph 函数
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

  code_type = "obs"
  code_url  = var.function_code_url

  user_data = jsonencode({
    PING_TOPIC_URN = var.ping_topic_urn
    LOG_STREAM_ID  = huaweicloud_lts_stream.this.id
  })
}

# -----------------------------------------------------------------------------
# APIG API（对接 FunctionGraph）
# -----------------------------------------------------------------------------

resource "huaweicloud_apig_api" "this" {
  name             = "${var.project_name}-api"
  group_id         = data.huaweicloud_apig_groups.default.groups[0].id
  instance_id      = huaweicloud_apig_instance.this.id
  type             = "FunctionGraph"
  request_method   = "ANY"
  request_path     = "/{proxy}"
  request_protocol = "HTTPS"
  matching         = "Prefix"
  cors             = true

  func_graph {
    function_urn     = huaweicloud_fgs_function.this.urn
    network_type     = "V1"
    request_protocol = "HTTPS"
    version          = "latest"
  }

  # 规避 provider 已知怪癖：apig_api 资源在 plan/apply 时会把 func_graph 当作
  # 必更新项（即使值与云端一致），而其底层修改接口不支持 func_graph 原地更新，
  # 报 "func_graph can't be updated"。func_graph 已在首次创建时落库，忽略其伪 diff。
  lifecycle {
    ignore_changes = [func_graph]
  }

  tags = [var.project_name]
}

# -----------------------------------------------------------------------------
# APIG 环境与发布
# API 只有发布到环境后才会产生对外可调用的入口；仅创建 API 定义不可调用
# -----------------------------------------------------------------------------

# 专享实例默认预置名为 RELEASE 的环境，直接引用既有环境，无需（也不能）重复创建
data "huaweicloud_apig_environments" "this" {
  instance_id = huaweicloud_apig_instance.this.id
  name        = var.environment_name
}

resource "huaweicloud_apig_api_publishment" "this" {
  instance_id = huaweicloud_apig_instance.this.id
  api_id      = huaweicloud_apig_api.this.id
  env_id      = data.huaweicloud_apig_environments.this.environments[0].id
  description = "Publish ${var.project_name} API to the release environment"
}

# -----------------------------------------------------------------------------
# 输出
# -----------------------------------------------------------------------------

output "function_urn" {
  value = huaweicloud_fgs_function.this.urn
}

output "apig_api_url" {
  description = "APIG 实例入口地址（调用地址的主机部分）"
  value       = "https://${huaweicloud_apig_instance.this.ingress_address}"
}

output "apig_group_id" {
  description = "API 所属分组 ID（DEFAULT 分组，构成对外调用地址的路径段之一）"
  value       = data.huaweicloud_apig_groups.default.groups[0].id
}

output "apig_environment_name" {
  description = "API 已发布到的环境名称"
  value       = var.environment_name
}

output "lts_stream_id" {
  value = huaweicloud_lts_stream.this.id
}

# API 发布后的对外调用地址（通用拼装）。
# 专享版无独立域名时，调用地址 = https://{入公网EIP公网地址}/{分组ID}/{环境ID}/{请求路径}。
output "apig_invoke_url" {
  description = "API 发布后的对外调用地址（APIG 入公网 EIP 公网入口；L3 端到端调用地址）"
  value       = "https://${huaweicloud_apig_instance.this.ingress_address}/${data.huaweicloud_apig_groups.default.groups[0].id}/${data.huaweicloud_apig_environments.this.environments[0].id}${huaweicloud_apig_api.this.request_path}"
}
