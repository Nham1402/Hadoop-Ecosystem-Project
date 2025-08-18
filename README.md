bigdata-banking-system/
├── docker-compose.yml
├── .env
├── scripts/
│   ├── init-swarm.sh
│   ├── deploy-stack.sh
│   ├── setup-nodes.sh
│   └── cleanup.sh
├── configs/
│   ├── hadoop/
│   │   ├── core-site.xml
│   │   ├── hdfs-site.xml
│   │   ├── yarn-site.xml
│   │   └── mapred-site.xml
│   ├── spark/
│   │   ├── spark-defaults.conf
│   │   └── spark-env.sh
│   ├── hive/
│   │   └── hive-site.xml
│   ├── hbase/
│   │   └── hbase-site.xml
│   ├── kafka/
│   │   └── server.properties
│   ├── flume/
│   │   └── flume.conf
│   └── airflow/
│       ├── airflow.cfg
│       └── webserver_config.py
├── data/
│   ├── banking-sample/
│   │   ├── transactions.csv
│   │   ├── customers.csv
│   │   └── accounts.csv
│   └── schemas/
│       ├── hive/
│       └── hbase/
├── dags/
│   ├── etl_banking_pipeline.py
│   ├── fraud_detection_pipeline.py
│   └── risk_analysis_pipeline.py
├── spark-jobs/
│   ├── fraud_detection.py
│   ├── risk_analytics.py
│   └── customer_segmentation.py
├── notebooks/
│   ├── data_exploration.ipynb
│   └── model_training.ipynb
└── monitoring/
    ├── prometheus.yml
    └── grafana/
        └── dashboards/
