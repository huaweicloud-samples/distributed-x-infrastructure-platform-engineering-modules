# worker-serverless-svc 模块

DMS Kafka 队列 + CCE 消费者 Deployment（无节点调度约束）。

## 用途

异步消费者服务，从 Kafka 持续拉取消息处理；不做节点形态约束，调度更灵活。

## 使用方式

```hcl
module "worker" {
  source = "../worker-serverless-svc"

  project_name  = "demo"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.private_subnet_one_id
  cluster_id    = module.cluster_env.cluster_id
  image_url     = "swr.cn-north-4.myhuaweicloud.com/demo/worker:latest"
  replicas      = 2
  kafka_flavor_id = "cluster.small"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_dms_kafka_instance.this` | DMS Kafka 实例（含业务 Topic 与死信 Topic） |
| `huaweicloud_cce_namespace.this` | CCE 命名空间 |
| `输出 deployment_yaml_hint` | K8s Deployment YAML 模板 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `kafka_brokers` | Kafka 接入地址 |
| `namespace_id` | 命名空间 ID |
| `deployment_yaml_hint` | K8s Deployment YAML 模板 |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
