# =============================================================================
# cae-webapp-svc
# 模块能力：SWR 镜像仓库 + CCE 命名空间，为云应用托管准备镜像与运行空间
# 资源构成：
#   - SWR 组织 / 镜像仓库（huaweicloud_swr_organization / huaweicloud_swr_repository）
#   - CCE 命名空间（huaweicloud_cce_namespace）
# 实现说明：CAE（云应用引擎）在当前 provider 版本（v1.97.1）无对应资源
#   （huaweicloud_cae_application 不存在），应用本体与 CronJob / Deployment 由 kubectl 部署，
#   本模块只落地镜像仓库与命名空间
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
  default = "cae-webapp-svc"
}
variable "organization_name" {
  type        = string
  description = "SWR 组织名"
}
variable "image_name" {
  type    = string
  default = "app"
}
variable "vpc_id" { type = string }
variable "cluster_id" { type = string }

# SWR 镜像仓库
resource "huaweicloud_swr_organization" "this" {
  name = var.organization_name
}

resource "huaweicloud_swr_repository" "this" {
  organization = huaweicloud_swr_organization.this.name
  name         = "${var.project_name}-${var.image_name}"
  description  = "${var.project_name} container image"
  is_public    = false
}

resource "huaweicloud_cce_namespace" "this" {
  cluster_id = var.cluster_id
  name       = var.project_name
}

output "swr_image_url" { value = format("swr.%s.myhuaweicloud.com/%s/%s:latest", var.region, huaweicloud_swr_organization.this.name, huaweicloud_swr_repository.this.name) }
output "namespace_id" { value = huaweicloud_cce_namespace.this.id }
