# backend-node-svc 模块

CCE 命名空间 + 后端 Service 工作负载（节点池调度）。

## 用途

常驻后端服务的容器工作负载模板，通过 nodeSelector 调度到节点池；服务间通过 K8s Service 互通。

## 使用方式

```hcl
module "backend" {
  source = "../backend-node-svc"

  project_name   = "demo"
  cluster_id     = module.node_env.cluster_id
  image_url      = "swr.cn-north-4.myhuaweicloud.com/demo/backend:latest"
  container_port = 8080
  replicas       = 2
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_cce_namespace.this` | CCE 命名空间 |
| `输出 deployment_yaml_hint` | K8s Deployment / Service YAML 模板（由 kubectl apply 部署） |

## 关键输出

| 输出 | 说明 |
|---|---|
| `namespace_id` | 命名空间 ID |
| `deployment_yaml_hint` | K8s Deployment / Service YAML 模板 |

## 实现说明

网络模型统一走 CNI（CCE 强制）；自动扩缩由 K8s HPA 承担。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
