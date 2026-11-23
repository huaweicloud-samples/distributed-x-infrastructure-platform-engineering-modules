# worker-function-svc 模块

DMS Kafka 队列 + FunctionGraph 消费函数。

## 用途

无服务器异步消费者，消息到达自动触发函数处理；适合突发流量、无需常驻容器的消费场景。

## 使用方式

```hcl
module "worker" {
  source = "../worker-function-svc"

  project_name      = "demo"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_one_id
  security_group_id = module.vpc.vpc_default_security_group_id
  function_code_url = "https://your-bucket.obs.cn-north-4.myhuaweicloud.com/worker.zip"
  kafka_flavor_id   = "cluster.small"
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_dms_kafka_instance.this` | DMS Kafka 实例 |
| `huaweicloud_dms_kafka_topic.processing / dlq` | 处理主题 / 死信主题 |
| `huaweicloud_fgs_function.this` | FunctionGraph 消费函数 |
| `huaweicloud_fgs_trigger.kafka` | Kafka 触发器，主题消息即为函数调用事件 |
| `huaweicloud_identity_agency.fgs` | 函数委托 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `function_urn` | 函数 URN |
| `kafka_instance_id / kafka_brokers` | Kafka 实例 ID / 接入地址 |
| `kafka_topic_names` | 处理主题与死信主题名称 |

## 实现说明

死信队列由独立 Kafka Topic 承载（业务约定 + 监控告警）；订阅投递由业务代码订阅 SMN 主题后写入 Kafka。

函数与 Kafka 实例同处一个 VPC；调用方提供的安全组须放行 9092 端口入站，否则 Kafka 触发器无法投递消息。函数以 `code_type = "obs"` 从 OBS 对象取码，`function_code_url` 需指向同区域的 zip 对象。

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
