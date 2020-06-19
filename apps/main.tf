

// provider "kubectl" {
//   load_config_file       = false
//   host                   = "${data.aws_eks_cluster.lt_cluster.endpoint}"
//   token                  = "${data.aws_eks_cluster.lt_cluster.main.token}"
//   cluster_ca_certificate = "${base64decode(data.aws_eks_cluster.lt_cluster.certificate_authority.0.data)}"
// }


resource "helm_release" "api" {
  name       = "api"
  repository = "http://incashme-helm.s3-website.ap-south-1.amazonaws.com" 
  repository = "https://incashme.github.io/index.yaml" 
  chart      = "portal-backend"
  version    = var.portal_backend_version
}


resource "helm_release" "postgres-pgb" {
  name       = "postgres-pgb"
  // repository = "./pgbouncer" 
  chart      = "./pgbouncer"

  values = [
    "${file("pgbouncer/values_write.yaml")}"
  ]
  set { name  = "username"        value = var.dbuser    }
  set { name  = "password"        value = var.dbpwd  }
  set { name  = "host"            value = var.db_write_host    }
  set { name  = "probes.database" value = var.dbname    }
}

resource "helm_release" "postgres-read-pgb" {
  name       = "postgres-read-pgb"
  // repository = "./pgbouncer" 
  chart      = "./pgbouncer"

  values = [
    "${file("pgbouncer/values.yaml")}"
  ]

  set { name  = "username"        value = var.dbuser    }
  set { name  = "password"        value = var.dbpwd  }
  set { name  = "host"            value = var.dbhost    }
  set { name  = "probes.database" value = var.dbname    }
}

resource "helm_release" "datadog" {
  name       = "dd"
  repository = "https://kubernetes-charts.storage.googleapis.com/" 
  chart      = "datadog"
  
  values = [
    "${file("datadog_values.yaml")}"
  ]
}


resource "kubernetes_service" "portal_api" {
  metadata {
    name = "portalback"
    annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
        "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "arn:aws:acm:ap-south-1:175714258900:certificate/72335690-60f4-4ae3-8fe6-3c78f4e375be"
        "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "https" 
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "portal-backend"
      "app.kubernetes.io/instance" = "api"
    }
    port {
      port        = 443
      target_port = 80
      name        = "https"
    }
    type = "LoadBalancer"
    external_traffic_policy =  "Local"
  }
}


resource "kubernetes_service" "redis" {
  metadata {
    name = "redis"
  }
  spec {
    external_name = var.redis_cluster
    type = "ExternalName"
  }
}

output "apilb_endpoint" {
  description = "Endpoint for API Loadbalancer"
  value       = kubernetes_service.portal_api.spec  
}


variable "portal_backend_version" {}
variable "redis_cluster"          {}
variable "dbuser"                 {}
variable "dbpwd"                  {}
variable "dbhost"                 {}
variable "dbname"                 {}
variable "db_write_host"          {}