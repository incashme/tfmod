data "aws_availability_zones" "available" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  snapshot_name = "${var.dmf_identifier}-redshift-db-snapshot-${random_string.suffix.result}"
}


// subgroup for dms

resource "aws_dms_replication_subnet_group" "default" {
  name       = "${var.dmf_identifier}-dms-group"
  description = "dmf subnet group"
  
  subnet_ids = var.db_subnets

  tags = {
    name = "Redshift - RDS DB subnet group"
    environment = var.envt
  }
}
 
// ------------------------------------------------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------------------------------------------------
// roles for dms

data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "dms-access-for-endpoint" {
  assume_role_policy = "${data.aws_iam_policy_document.dms_assume_role.json}"
  name               = "dms-access-for-endpoint"
}

resource "aws_iam_role_policy_attachment" "dms-access-for-endpoint-AmazonDMSRedshiftS3Role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"
  role       = "${aws_iam_role.dms-access-for-endpoint.name}"
}

resource "aws_iam_role" "dms-cloudwatch-logs-role" {
  assume_role_policy = "${data.aws_iam_policy_document.dms_assume_role.json}"
  name               = "dms-cloudwatch-logs-role"
}

resource "aws_iam_role_policy_attachment" "dms-cloudwatch-logs-role-AmazonDMSCloudWatchLogsRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = "${aws_iam_role.dms-cloudwatch-logs-role.name}"
}

resource "aws_iam_role" "dms-vpc-role" {
  assume_role_policy = "${data.aws_iam_policy_document.dms_assume_role.json}"
  name               = "dms-vpc-role"
}

resource "aws_iam_role_policy_attachment" "dms-vpc-role-AmazonDMSVPCManagementRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = "${aws_iam_role.dms-vpc-role.name}"
}


# Create a new replication instance
resource "aws_dms_replication_instance" "dmsri" {

  allocated_storage            = var.allocated_storage
  engine_version               = var.engine_version

  apply_immediately            = true
  auto_minor_version_upgrade   = true
  multi_az                     = false

  replication_instance_class   = var.inst_class
  replication_instance_id      = var.dmf_identifier
  replication_subnet_group_id  = "${aws_dms_replication_subnet_group.default.id}"
  vpc_security_group_ids       = var.db_secgrps

  preferred_maintenance_window = "sun:10:30-sun:14:30"

//   availability_zones           = data.aws_availability_zones.available.names
//   publicly_accessible          = true

  tags = {
    envt = var.envt
  }

}

// ------------------------------------------------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------------------------------------------------
// source and destination of replication endpoints

resource "aws_dms_endpoint" "source" {

  database_name               = var.source_dbname
  username                    = var.source_dbuser
  password                    = var.source_dbpasswd
  port                        = var.source_dbport

  endpoint_type               = "source"
  endpoint_id                 = "${var.dmf_identifier}-source"

  engine_name                 = var.source_engine
  server_name                 = var.source_server

  tags = {
    envt = var.envt
  }
}

resource "aws_dms_endpoint" "dest" {

  database_name               = var.dest_dbname
  username                    = var.dest_dbuser
  password                    = var.dest_dbpasswd
  port                        = var.dest_dbport

  endpoint_type               = "target"
  endpoint_id                 = "${var.dmf_identifier}-dest"

  engine_name                 = var.dest_engine
  server_name                 = var.dest_server

  tags = {
    envt = var.envt
  }
}

// ------------------------------------------------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------------------------------------------------
// Replication task connecting source and destination



resource "aws_dms_replication_task" "task" {
  cdc_start_time            = 1484346880
  migration_type            = "full-load"

  replication_instance_arn  = "${aws_dms_replication_instance.dmsri.replication_instance_arn}"
  replication_task_id       = "${var.dmf_identifier}-dms-replication-task"
  
  source_endpoint_arn       = "${aws_dms_endpoint.soure.endpoint_arn}"
  target_endpoint_arn       = "${aws_dms_endpoint.dest.endpoint_arn}"

  replication_task_settings = <<EOF
{
  "TargetMetadata": {
    "TargetSchema": "",
    "SupportLobs": true,
    "FullLobMode": false,
    "LobChunkSize": 64,
    "LimitedSizeLobMode": true,
    "LobMaxSize": 32,
    "InlineLobMaxSize": 0,
    "LoadMaxFileSize": 0,
    "ParallelLoadThreads": 0,
    "ParallelLoadBufferSize":0,
    "ParallelLoadQueuesPerThread": 1,
    "ParallelApplyThreads": 0,
    "ParallelApplyBufferSize": 50,
    "ParallelApplyQueuesPerThread": 1,    
    "BatchApplyEnabled": false,
    "TaskRecoveryTableEnabled": false
  },
  "FullLoadSettings": {
    "TargetTablePrepMode": "DO_NOTHING",
    "CreatePkAfterFullLoad": false,
    "StopTaskCachedChangesApplied": false,
    "StopTaskCachedChangesNotApplied": false,
    "MaxFullLoadSubTasks": 8,
    "TransactionConsistencyTimeout": 600,
    "CommitRate": 10000
  },
  "Logging": {
    "EnableLogging": false
  },
  "ControlTablesSettings": {
    "ControlSchema":"",
    "HistoryTimeslotInMinutes":5,
    "HistoryTableEnabled": false,
    "SuspendedTablesTableEnabled": false,
    "StatusTableEnabled": false
  },
  "StreamBufferSettings": {
    "StreamBufferCount": 3,
    "StreamBufferSizeInMB": 8
  },
  "ChangeProcessingTuning": { 
    "BatchApplyPreserveTransaction": true, 
    "BatchApplyTimeoutMin": 1, 
    "BatchApplyTimeoutMax": 30, 
    "BatchApplyMemoryLimit": 500, 
    "BatchSplitSize": 0, 
    "MinTransactionSize": 1000, 
    "CommitTimeout": 1, 
    "MemoryLimitTotal": 1024, 
    "MemoryKeepTime": 60, 
    "StatementCacheSize": 50 
  },
  "ChangeProcessingDdlHandlingPolicy": {
    "HandleSourceTableDropped": true,
    "HandleSourceTableTruncated": true,
    "HandleSourceTableAltered": true
  },
  "LoopbackPreventionSettings": {
    "EnableLoopbackPrevention": true,
    "SourceSchema": "LOOP-DATA",
    "TargetSchema": "loop-data"
  },
  "ValidationSettings": {
     "EnableValidation": true,
     "ThreadCount": 5
  },
  "CharacterSetSettings": {
    "CharacterReplacements": [ {
        "SourceCharacterCodePoint": 35,
        "TargetCharacterCodePoint": 52
      }, {
        "SourceCharacterCodePoint": 37,
        "TargetCharacterCodePoint": 103
      }
    ],
    "CharacterSetSupport": {
      "CharacterSet": "UTF16_PlatformEndian",
      "ReplaceWithCharacterCodePoint": 0
    }
  },
  "BeforeImageSettings": {
    "EnableBeforeImage": false,
    "FieldName": "",  
    "ColumnFilter": pk-only
  },
  "ErrorBehavior": {
    "DataErrorPolicy": "LOG_ERROR",
    "DataTruncationErrorPolicy":"LOG_ERROR",
    "DataErrorEscalationPolicy":"SUSPEND_TABLE",
    "DataErrorEscalationCount": 50,
    "TableErrorPolicy":"SUSPEND_TABLE",
    "TableErrorEscalationPolicy":"STOP_TASK",
    "TableErrorEscalationCount": 50,
    "RecoverableErrorCount": 0,
    "RecoverableErrorInterval": 5,
    "RecoverableErrorThrottling": true,
    "RecoverableErrorThrottlingMax": 1800,
    "ApplyErrorDeletePolicy":"IGNORE_RECORD",
    "ApplyErrorInsertPolicy":"LOG_ERROR",
    "ApplyErrorUpdatePolicy":"LOG_ERROR",
    "ApplyErrorEscalationPolicy":"LOG_ERROR",
    "ApplyErrorEscalationCount": 0,
    "FullLoadIgnoreConflicts": true
  }
}
EOF

  table_mappings            = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"%\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"

  tags = {
    envt = var.envt
  }

}

variable "dmf_identifier"    {}
variable "inst_class"        {}
variable "allocated_storage" {}
variable "engine_version"    {}
variable "db_subnets"         { type=list(string) }  
variable "db_secgrps"         { type=list(string) }  
variable "envt"               {} 


variable "source_dbname"   {}
variable "source_dbuser"   {}
variable "source_dbpasswd" {}
variable "source_dbport"   {}
variable "source_engine"   {}
variable "source_server"   {}

variable "dest_dbname"   {}
variable "dest_dbuser"   {}
variable "dest_dbpasswd" {}
variable "dest_dbport"   {}
variable "dest_engine"   {}
variable "dest_server"   {}

