# cae-webapp-svc 模块

SWR 镜像仓库 + CCE 命名空间，为云应用托管准备镜像与运行空间。

## 用途

准备容器镜像仓库与命名空间，作为云应用（CAE）或 CCE 工作负载的前置资源。

## 使用方式

```hcl
module "webapp" {
  source = "../cae-webapp-svc"

  project_name   = "demo"
  image_name     = "webapp"
  vpc_id         = module.vpc.vpc_id
  cluster_id     = module.cluster_env.cluster_id
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_swr_organization.this` | SWR 组织 |
| `huaweicloud_swr_repository.this` | SWR 镜像仓库 |
| `huaweicloud_cce_namespace.this` | CCE 命名空间 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `swr_image_url` | 镜像推送地址 |
| `namespace_id` | 命名空间 ID |

## 实现说明

CAE（云应用引擎）在当前 provider 版本（v1.97.1）无对应资源，应用本体与 CronJob / Deployment 由 kubectl 部署，本模块只落地镜像仓库与命名空间。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
