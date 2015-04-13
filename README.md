coreos-rabbitmq
===============

RabbitMQ Cluster For CoreOS

##### Running cluster:

```
fleetctl submit units/rabbitmq*       # Submits service to systemd

fleetctl start rabbitmq@1
fleetctl start rabbitmq@2
...
```

