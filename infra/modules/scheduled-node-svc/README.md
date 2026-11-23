# scheduled-node-svc 模块

FunctionGraph 定时触发 + CCE CronJob（节点池调度）。

## 用途

周期性批量任务，主体为节点池调度的容器作业；定时触发由 FunctionGraph 统一编排。

## 使用方式

```hcl
module "scheduled" {
  source = "../scheduled-node-svc"

  project_name    = "demo"
  cluster_id      = module.node_env.cluster_id
  image_url       = "swr.cn-north-4.myhuaweicloud.com/demo/job:latest"
  cron_expression = "0 0 2 * * ?"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_cce_namespace.this` | CCE 命名空间 |
| `输出 cronjob_yaml_hint` | K8s CronJob YAML 模板（由 kubectl apply 部署） |

## 关键输出

| 输出 | 说明 |
|---|---|
| `namespace_id` | 命名空间 ID |
| `cronjob_yaml_hint` | K8s CronJob YAML 模板 |

## 实现说明

工作负载访问云服务的授权由 CCE 工作负载委托承担。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
