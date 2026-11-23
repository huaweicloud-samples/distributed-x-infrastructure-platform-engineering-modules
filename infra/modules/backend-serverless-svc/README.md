# backend-serverless-svc 模块

CCE 命名空间 + 后端 Service 工作负载（无节点选择约束）。

## 用途

常驻后端服务的容器工作负载模板，不做节点形态约束；服务发现使用 K8s Headless Service。

## 使用方式

```hcl
module "backend" {
  source = "../backend-serverless-svc"

  project_name   = "demo"
  cluster_id     = module.cluster_env.cluster_id
  image_url      = "swr.cn-north-4.myhuaweicloud.com/demo/backend:latest"
  container_port = 8080
  replicas       = 2
  cpu            = "0.5"
  memory         = "1Gi"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_cce_namespace.this` | CCE 命名空间 |
| `输出 deployment_yaml_hint` | K8s Deployment / Service / HPA YAML 模板 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `namespace_id` | 命名空间 ID |
| `deployment_yaml_hint` | K8s Deployment / Service / HPA YAML 模板 |

## 实现说明

容器组网络使用 IP 类型 Service 与 CNI 网络模型；自动扩缩由 HPA 按 CPU / 内存利用率承担。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
