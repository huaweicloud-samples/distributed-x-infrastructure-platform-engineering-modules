# =============================================================================
# functiongraph-vpc
# 模块能力：单 VPC + 单 FunctionGraph 函数（函数在 VPC 内运行的最小组合）
# 资源构成：VPC、子网、安全组、FunctionGraph 函数（含 VPC 网络配置）
# 实现说明：VPC 与子网直接由 huaweicloud_vpc / huaweicloud_vpc_subnet 声明，单可用区
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
  default = "functiongraph-vpc"
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
  default = 30
}
variable "function_name" {
  type    = string
  default = "vpc-function"
}
# VPC
resource "huaweicloud_vpc" "this" {
  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
}

resource "huaweicloud_vpc_subnet" "public" {
  name       = "${var.project_name}-public"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = "10.0.101.0/24"
  gateway_ip = "10.0.101.1"
}

resource "huaweicloud_vpc_subnet" "private" {
  name       = "${var.project_name}-private"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = "10.0.1.0/24"
  gateway_ip = "10.0.1.1"
}

# 安全组
resource "huaweicloud_networking_secgroup" "this" {
  name = "${var.project_name}-sg"
}

resource "huaweicloud_networking_secgroup_rule" "egress_all" {
  direction        = "egress"
  ethertype        = "IPv4"
  remote_ip_prefix = "0.0.0.0/0"
  # protocol 省略 = 全协议放行
  security_group_id = huaweicloud_networking_secgroup.this.id
}

# FunctionGraph 委托
resource "huaweicloud_identity_agency" "fgs" {
  name        = "${var.project_name}-fgs-agency"
  description = "Agency for functiongraph-vpc FunctionGraph"
  duration    = "FOREVER"
  # 云服务委托对象：FunctionGraph 服务主体。服务主体必须写在 delegated_service_name
  # （与 delegated_domain_name 互斥），写在 domain 上会造成持续 diff
  delegated_service_name = "op_svc_cff"

  project_role {
    project = var.region
    roles   = ["VPC Administrator", "OBS OperateAccess"]
  }
}

# FunctionGraph 函数
resource "huaweicloud_fgs_function" "this" {
  name        = var.function_name
  agency      = huaweicloud_identity_agency.fgs.name
  handler     = var.function_handler
  memory_size = var.function_memory_mb
  timeout     = var.function_timeout_s
  runtime     = var.function_runtime

  # 函数所属应用分组（app 名）：需以字母开头，仅允许字母、数字与下划线
  app = "default"

  code_type = "obs"
  code_url  = var.function_code_url

  # VPC 接入：FunctionGraph 只接受单个子网
  vpc_id     = huaweicloud_vpc.this.id
  network_id = huaweicloud_vpc_subnet.private.id
}

output "vpc_id" { value = huaweicloud_vpc.this.id }
output "subnet_id" { value = huaweicloud_vpc_subnet.private.id }
output "security_group_id" { value = huaweicloud_networking_secgroup.this.id }
output "function_urn" { value = huaweicloud_fgs_function.this.urn }
