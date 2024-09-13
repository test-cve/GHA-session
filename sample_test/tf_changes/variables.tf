##############################################################################
# Input Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "APIkey that's associated with the account to use, set via environment variable TF_VAR_ibmcloud_api_key"
  type        = string
  sensitive   = true
  default     = null
}

variable "cluster_id" {
  type        = string
  description = "Id of the target IBM Cloud OpenShift Cluster"
}

variable "lb_subnet_ids" {
  type        = list(string)
  description = "List of subnets to attach the ingress gateway's public VPC ALB to. The default for an ALB is to attach it to all subnets"
  default     = []
}

variable "lb_subnet_ids_and_zones" {
  type        = map(string)
  description = "Map of subnets to their zones. Required for configuring an ingress which uses NLBs, which are single-zone"
  default     = {}
}

variable "service_mesh_control_planes" {
  type = list(object({
    name      = string
    namespace = string
    runtime = optional(object({
      pod = optional(object({
        nodeSelector = optional(object({
          name  = string
          value = string
        }))
        tolerations = optional(list(object({
          key    = string
          value  = string
          effect = string
        })))
      }))
    }))
    gateways = optional(object({
      egress = optional(object({
        enabled = optional(bool, true)
        nodeSelector = optional(object({
          name  = string
          value = string
        }))
        tolerations = optional(list(object({
          key    = string
          value  = string
          effect = string
        })))
        deployment = optional(object({
          autoScaling = optional(object({
            maxReplicas = optional(number)
            minReplicas = optional(number)
          }))
        }))
        haAntiAffinity = optional(bool)
        service = optional(object({
          additionalPorts = optional(list(object({
            name       = string
            port       = number
            targetPort = number
            protocol   = string
          })))
          metadata = optional(object({
            labels = optional(list(object({
              name  = string
              value = string
            })))
          }))
        }))
      }))
      ingress = optional(object({
        enabled = optional(bool, true)
        nlb     = optional(bool)
        nodeSelector = optional(object({
          name  = string
          value = string
        }))
        tolerations = optional(list(object({
          key    = string
          value  = string
          effect = string
        })))
        deployment = optional(object({
          autoScaling = optional(object({
            maxReplicas = optional(number)
            minReplicas = optional(number)
          }))
        }))
        haAntiAffinity = optional(bool)
        service = optional(object({
          type = optional(string)
          additionalPorts = optional(list(object({
            name       = string
            port       = number
            targetPort = number
            protocol   = string
          })))
          externalTrafficPolicy = optional(string)
          metadata = optional(object({
            annotations = optional(list(object({
              name  = string
              value = string
            })))
            labels = optional(list(object({
              name  = string
              value = string
            })))
          }))
        }))
        proxyProtocolEnabled      = optional(bool)
        proxyProtocolDefaultPorts = optional(list(number))
      }))
      additionalIngress = optional(map(object({
        nlb = optional(bool)
        sDNLB = optional(object({
          createSDNLB        = bool
          enableCSEProxy     = bool
          cseProxyIstioLabel = optional(string)
          cseProxyPort       = optional(number)
          vpcServiceCRN      = optional(string)
          additionalPorts = optional(list(object({
            name       = string
            port       = number
            targetPort = number
            protocol   = string
          })))
        }))
        nodeSelector = optional(object({
          name  = string
          value = string
        }))
        tolerations = optional(list(object({
          key    = string
          value  = string
          effect = string
        })))
        deployment = optional(object({
          autoScaling = optional(object({
            maxReplicas = optional(number)
            minReplicas = optional(number)
          }))
        }))
        haAntiAffinity = optional(bool)
        service = optional(object({
          type = optional(string)
          additionalPorts = optional(list(object({
            name       = string
            port       = number
            targetPort = number
            protocol   = string
          })))
          externalTrafficPolicy = optional(string)
          metadata = optional(object({
            annotations = optional(list(object({
              name  = string
              value = string
            })))
            labels = optional(list(object({
              name  = string
              value = string
            })))
          }))
        }))
      })))
      additionalEgress = optional(map(object({
        enabled   = optional(bool)
        namespace = optional(string)
        nodeSelector = optional(object({
          name  = string
          value = string
        }))
        tolerations = optional(list(object({
          key    = string
          value  = string
          effect = string
        })))
        deployment = optional(object({
          autoScaling = optional(object({
            maxReplicas = optional(number)
            minReplicas = optional(number)
          }))
        }))
        haAntiAffinity = optional(bool)
        service = optional(object({
          additionalPorts = optional(list(object({
            name       = string
            port       = number
            targetPort = number
            protocol   = string
          })))
          metadata = optional(object({
            labels = optional(list(object({
              name  = string
              value = string
            })))
          }))
        }))
      })))
    }))
    tracing : optional(object({
      sampling = optional(number, 10000)
      type     = optional(string, "None")
    }))
    proxy = optional(object({
      accessLogging = optional(object({
        file = optional(object({
          encoding = optional(string)
          format   = optional(string)
        }))
      }))
    }))
    addons = optional(object({
      kiali = optional(object({
        enabled = optional(bool, false)
        dashboard = optional(object({
          viewOnlyMode = optional(bool, true)
        }), null)
        ingress = optional(object({
          enabled = optional(bool, false)
        }), null)
      }))
      jaeger = optional(object({
        enabled = optional(bool, false)
        install = optional(object({
          storage = optional(object({
            type = optional(string, "Memory")
          }), null)
          ingress = optional(object({
            enabled = optional(bool, false)
          }), null)
        }), null)
        tracingSampling = optional(number, 10000)
        tracingType     = optional(string, "None")
      }), null)
      grafana = optional(object({
        enabled = bool
      }))
      prometheus = optional(object({
        enabled = bool
      }))
    }))
    enrolled_namespaces = optional(list(string))
    meshConfig = optional(object({
      extensionProviders = optional(list(any))
      discoverySelectors = optional(list(any))
    }))
  }))
  description = "Service Mesh control planes"
  default = [
    {
      namespace = "istio-system"
      name      = "basic-with-mtls"
      runtime = {
        pod = {
          nodeSelector = {
            name : "ibm-cloud.kubernetes.io/worker-pool-name"
            value : "default"
          }
        }
      }
      gateways = {
        egress = {
          haAntiAffinity = true
          nodeSelector = {
            name : "ibm-cloud.kubernetes.io/worker-pool-name"
            value : "edge"
          }
          tolerations = [
            {
              key : "dedicated"
              value : "edge"
              effect : "NoExecute"
            }
          ]
        }
        ingress = {
          haAntiAffinity = true
          nodeSelector = {
            name : "ibm-cloud.kubernetes.io/worker-pool-name"
            value : "edge"
          }
          tolerations = [
            {
              key : "dedicated"
              value : "edge"
              effect : "NoExecute"
            }
          ]
          service = {
            type                  = "LoadBalancer"
            externalTrafficPolicy = "Local"
            metadata = {
              annotations = [
                {
                  name  = "service.kubernetes.io/ibm-load-balancer-cloud-provider-ip-type"
                  value = "public"
                }
              ]
            }
          }
          proxyProtocolEnabled      = false
          proxyProtocolDefaultPorts = [8080, 8443, 15021]
        },
        additionalEgress = {
          transit-egress = {
            enabled   = true
            namespace = "istio-system"
            nodeSelector = {
              name  = "ibm-cloud.kubernetes.io/worker-pool-name"
              value = "transit"
            }
            tolerations = [{
              key : "dedicated"
              value : "transit"
              effect : "NoExecute"
            }]
            haAntiAffinity = true
          }
        }
      }
      proxy = {
        accessLogging = {
          file = {
            encoding = "JSON"
            format   = "[%START_TIME%] [%REQ(:AUTHORITY)%] [%BYTES_RECEIVED%] [%BYTES_SENT%] [%DOWNSTREAM_LOCAL_ADDRESS%] [%DOWNSTREAM_LOCAL_ADDRESS%] [%DOWNSTREAM_REMOTE_ADDRESS%] [%DOWNSTREAM_TLS_VERSION%] [%DURATION%] [%REQUEST_DURATION%] [%RESPONSE_DURATION%] [%RESPONSE_TX_DURATION%] [%DYNAMIC_METADATA(istio.mixer:status)%] [%REQ(:METHOD)%] [%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%] [%PROTOCOL%] [%REQ(X-REQUEST-ID)%] [%REQUESTED_SERVER_NAME%] [%RESPONSE_CODE%] [%RESPONSE_CODE_DETAILS%] [%RESPONSE_FLAGS%] [%ROUTE_NAME%] [%START_TIME%] [%UPSTREAM_CLUSTER%] [%UPSTREAM_HOST%] [%UPSTREAM_LOCAL_ADDRESS%] [%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%] [%UPSTREAM_TRANSPORT_FAILURE_REASON%] [%REQ(USER-AGENT)%] [%REQ(X-FORWARDED-FOR)%] [%REQ(X-ENVOY-ATTEMPT-COUNT)%]"
          }
        }
      }
    }
  ]
}

variable "release_name_sm_control_plane" {
  type        = string
  description = "Name for the controlplane helm release."
  default     = "service-mesh-control-plane"
  nullable    = false
}

variable "release_name_sm_cse_proxy" {
  type        = string
  description = "Name to use for the cse proxy helm chart."
  default     = "service-mesh-cse-proxy"
  nullable    = false
}

variable "release_name_sm_ingress_proxy" {
  type        = string
  description = "Name to use for the ingress proxy helm chart."
  default     = "service-mesh-ingress-proxy"
  nullable    = false
}

variable "release_namespace_sm_control_plane" {
  type        = string
  description = "Namespace to use for the controlplane helm release."
  default     = "default"
  nullable    = false
}

variable "release_namespace_sm_cse_proxy" {
  type        = string
  description = "Namespace to use for the cse proxy helm release."
  default     = "default"
  nullable    = false
}

variable "release_namespace_sm_ingress_proxy" {
  type        = string
  description = "Namespace to use for the ingress proxy helm release."
  default     = "default"
  nullable    = false
}

variable "create_ingress_subdomains" {
  type        = bool
  description = "If set to true, the module also registers each istio gateway in an IBM-provided subdomain with associated TLS certificates. See https://cloud.ibm.com/docs/containers?topic=containers-vpc-lbaas#vpc_lb_dns for details."
  default     = false
}

variable "deploy_operators" {
  type        = bool
  description = "Enable installing RedHat Service Mesh Operator and, if enabled, addons operators"
  default     = true
}

variable "deploy_addons" {
  description = "Allow to enable the deployment of each RedHat Service Mesh addon operators and to configure the single namespace operators target namespace. Default is false for each addon and istio-system for the target namespace."
  type = object({
    singlenamespace_addons = object({
      prometheus = optional(bool, false)
    })
    singlenamespace_addons_target = optional(string, "istio-system")
    allnamespaces_addons = object({
      grafana       = optional(bool, false)
      kiali         = optional(bool, false)
      elasticsearch = optional(bool, false)
      jaeger        = optional(bool, false)
    })
  })
  default = {
    singlenamespace_addons = {
      prometheus = false
    }
    singlenamespace_addons_target = "istio-system"
    allnamespaces_addons = {
      grafana       = false
      kiali         = false
      elasticsearch = false
      jaeger        = false
    }
  }
}

variable "develop_mode" {
  type        = bool
  description = "If true, output more logs, and reduce some wait periods"
  default     = false
}

variable "confirm_sdnlb_readiness" {
  type        = bool
  description = "If true and sDNLB is to be created in the serviceMesh profile, the module checks for the sdnlb readiness before going on. When false it doesn't wait: if sdnlb fails to be ready, the returned sdnlbIPs list will be empty"
  default     = true
}

variable "cluster_config_endpoint_type" {
  description = "Specify which type of endpoint to use for for cluster config access: 'default', 'private', 'vpe', 'link'. 'default' value will use the default endpoint of the cluster."
  type        = string
  default     = "default"
  nullable    = false # use default if null is passed in
  validation {
    error_message = "Invalid Endpoint Type! Valid values are 'default', 'private', 'vpe', or 'link'"
    condition     = contains(["default", "private", "vpe", "link"], var.cluster_config_endpoint_type)
  }
}
##############################################################################
