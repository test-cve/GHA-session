##############################################################################
# OCP Service Mesh
#
# Deploy the Service Mesh operator on an OCP cluster, if needed, and set up
# one or several service mesh control plane(s)
##############################################################################

##############################################################################
# Locals
##############################################################################

locals {
  operator_namespace               = "openshift-operators"
  operator_addons_single_namespace = "openshift-operators-singlens"

  operator_addons_single_namespace_target = var.deploy_addons.singlenamespace_addons_target != "" && var.deploy_addons.singlenamespace_addons_target != null ? var.deploy_addons.singlenamespace_addons_target : "istio-system"

  # local path to the helm chart for the RedHat Service Mesh operator
  chart_path_sm_operator                      = "service-mesh"
  chart_path_sm_operator_addons_with_singlens = "service-mesh-addons-singlenamespace"
  # helm release name for the RedHat Service Mesh operator set to the value of the chart path
  release_name_sm_operator = local.chart_path_sm_operator

  # local path to the chart for the service-mesh controlplane
  chart_path_sm_control_plane = "service-mesh-control-plane"

  # local path to the chart for the cse-proxy
  chart_path_sm_cse_proxy = "service-mesh-cse-proxy"

  # local path to the chart for the ingress-proxy
  chart_path_sm_ingress_proxy = "service-mesh-ingress-proxy"

  controlplanes_config = var.service_mesh_control_planes
  subnet_values        = <<EOT
%{if length(var.lb_subnet_ids) > 0~}
lb_subnets:
%{for subnet in var.lb_subnet_ids~}
  - ${subnet}
%{endfor~}
%{endif~}
EOT
  subnet_zone_values   = <<EOT
%{if length(var.lb_subnet_ids_and_zones) > 0~}
lb_subnet_ids_and_zones:
%{for subnet_id, subnet_zone in var.lb_subnet_ids_and_zones~}
  ${subnet_id}: ${subnet_zone}
%{endfor~}
%{endif~}
EOT

  # Wait periods are overally conservative on purpose to cover majority of case. Divide them by 10 during dev
  sleep_create  = var.develop_mode ? "60s" : "600s"
  sleep_destroy = var.develop_mode ? "36s" : "360s"

  # retrieve from controlplanes the list of sdnlb(s) namespace and svc(s) name
  sdnlb_namespaces_list = [
    # cycling over the controlplane configs (c is the counter and x is the configuration)
    for c, x in local.controlplanes_config : {
      namespace = x.namespace
      svcs = x.gateways.additionalIngress == null ? [] : [
        # cycling over additionalIngress and adding single element to the array only if element sDNLB.createSDNLB is true
        for w, z in x.gateways.additionalIngress :
        w if z.sDNLB.createSDNLB == true
      ]
    }
  ]

  # the code below is commented to keep distinction between the standard public ingress gw (istio-ingressgateway) and the additional ones in additionalIngress
  # it is possible to replace the two steps below for local.full_public_ingress_namespaces_list and local.public_ingress_namespaces_list if it acceptable that
  # data.kubernetes_service.istio_ingressgateway returns the load balancer hostname for every first public gateway even if it is not the default
  # istio-ingressgateway one

  # public_ingress_namespaces_list = [
  #   # cycling over the controlplane configs (c is the counter and x is the configuration)
  #   for c, x in local.controlplanes_config : {
  #     namespace = x.namespace
  #     # cycling over additionalIngress and adding single element to the array only if element sDNLB.createSDNLB is false
  #     # concat makes a single list with the standard gw and the additional gw
  #     # compat removes the empty/null elements
  #     svcs = compact(concat([x.gateways.ingress.enabled == true ? "istio-ingressgateway" : null], [for w, z in x.gateways.additionalIngress : w if z.sDNLB.createSDNLB == false]))
  #   }
  # ]

  # retrieve from all the istio controlplanes the list of the couples [namespace, list of public ingresses name]
  # getting default public ingress istio-ingressgateway only if enabled
  # getting the additionalIngresses where sDNLB.createSDNLB is false (public gateway)
  full_public_ingress_namespaces_list = [
    # cycling over the controlplane configs (c is the counter and x is the configuration)
    for c, x in local.controlplanes_config : {
      namespace     = x.namespace
      publicIngress = x.gateways.ingress != null ? (x.gateways.ingress.enabled == true ? "istio-ingressgateway" : null) : null
      additionalIngresses = x.gateways.additionalIngress == null ? [] : [
        # cycling over additionalIngress and adding single element to the array only if element sDNLB.createSDNLB is false (it is not a sDNLB)
        for w, z in x.gateways.additionalIngress :
        w if z.sDNLB.createSDNLB == false
      ]
    }
  ]

  # collapsing the full list of public ingresses & additional ingresses into a single list for for_each usage
  public_ingress_namespaces_list = [
    for l in local.full_public_ingress_namespaces_list :
    {
      namespace = l.namespace
      svcs      = l.publicIngress != null ? concat([l.publicIngress], l.additionalIngresses) : l.additionalIngresses
    }
  ]

  # filtering the namespaces having at least one public ingress svc
  filtered_public_ingress_namespaces_list = [
    for l in local.public_ingress_namespaces_list :
    {
      namespace = l.namespace
      svcs      = l.svcs
    }
    if length(l.svcs) > 0
  ]

  # filtering the namespaces having at least one sDNLB LB ingress svc
  filtered_sdnlb_namespaces_list = [
    for l in local.sdnlb_namespaces_list :
    {
      namespace = l.namespace
      svcs      = l.svcs
    }
    if length(l.svcs) > 0
  ]

  plain_filtered_public_ingress_namespaces_list = merge([for k, v in local.filtered_public_ingress_namespaces_list : {
    for svc in v.svcs : "${v.namespace}/${svc}" => { namespace : v.namespace, service : svc }
  }]...)

  plain_filtered_sdnlb_namespaces_list = merge([for k, v in local.filtered_sdnlb_namespaces_list : {
    for svc in v.svcs : "${v.namespace}/${svc}" => { namespace : v.namespace, service : svc }
  }]...)

  validate_ibmcloud_api_key_cnd = var.create_ingress_subdomains == true && var.ibmcloud_api_key == null
  validate_ibmcloud_api_key_msg = "ibmcloud_api_key must also be set when create_ingress_subdomains is set to true."
  # tflint-ignore: terraform_unused_declarations
  validate_ibmcloud_api_key_chk = regex(
    "^${local.validate_ibmcloud_api_key_msg}$",
    (!local.validate_ibmcloud_api_key_cnd
      ? local.validate_ibmcloud_api_key_msg
  : ""))

}

##############################################################################
# Retrieve information about all the Kubernetes configuration files and
# certificates to access the cluster in order to run kubectl / oc commands
##############################################################################

data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id = var.cluster_id
  config_dir      = "${path.module}/kubeconfig"                                                             # See https://github.ibm.com/GoldenEye/issues/issues/552
  endpoint_type   = var.cluster_config_endpoint_type != "default" ? var.cluster_config_endpoint_type : null # null represents default
}

##############################################################################
# RedHat Service Mesh Operator, and its dependencies
##############################################################################

# installing helm chart to enable subscriptions for single namespaces operators (when required)
# if a further operators is added to this set, its check must be added to the count in this resource
resource "helm_release" "service_mesh_singlens_operators" {
  depends_on = [data.ibm_container_cluster_config.cluster_config]
  count      = var.deploy_addons.singlenamespace_addons.prometheus == true ? 1 : 0

  name              = "${local.release_name_sm_operator}-addons"
  chart             = "${path.module}/chart/${local.chart_path_sm_operator_addons_with_singlens}"
  namespace         = local.operator_addons_single_namespace
  create_namespace  = true
  timeout           = 300
  dependency_update = true
  force_update      = false
  cleanup_on_fail   = false
  wait              = true

  disable_openapi_validation = false

  set {
    name  = "operators.deployprometheus"
    type  = "string"
    value = var.deploy_addons.singlenamespace_addons.prometheus
  }

  set {
    name  = "operators.namespace"
    type  = "string"
    value = local.operator_addons_single_namespace
  }

  set {
    name  = "operators.targetnamespace"
    type  = "string"
    value = local.operator_addons_single_namespace_target
  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/approve-install-plan.sh ${local.operator_addons_single_namespace}"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = data.ibm_container_cluster_config.cluster_config.config_file_path
    }
  }
}

# installing helm chart to enable subscriptions for AllNamespaces operators (service-mesh-operator and addons)
# dependency on helm_release.service_mesh_singlens_operators is needed if any of the single namespace operators is to be enabled
resource "helm_release" "service_mesh_operator" {
  depends_on = [data.ibm_container_cluster_config.cluster_config, helm_release.service_mesh_singlens_operators]
  count      = var.deploy_operators == true ? 1 : 0

  name              = local.release_name_sm_operator
  chart             = "${path.module}/chart/${local.chart_path_sm_operator}"
  namespace         = local.operator_namespace
  create_namespace  = true
  timeout           = 300
  dependency_update = true
  force_update      = false
  cleanup_on_fail   = false
  wait              = true

  disable_openapi_validation = false

  set {
    name  = "operators.deploygrafana"
    type  = "string"
    value = var.deploy_addons.allnamespaces_addons.grafana
  }

  set {
    name  = "operators.deployjaeger"
    type  = "string"
    value = var.deploy_addons.allnamespaces_addons.jaeger
  }

  set {
    name  = "operators.deployelasticsearch"
    type  = "string"
    value = var.deploy_addons.allnamespaces_addons.elasticsearch
  }

  set {
    name  = "operators.deploykiali"
    type  = "string"
    value = var.deploy_addons.allnamespaces_addons.kiali
  }

  set {
    name  = "operators.namespace"
    type  = "string"
    value = local.operator_namespace
  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/approve-install-plan.sh ${local.operator_namespace}"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = data.ibm_container_cluster_config.cluster_config.config_file_path
    }
  }
}

# On create: give time for the istio pod operator to warm-up up (see bug report for RH linked at https://github.ibm.com/GoldenEye/issues/issues/58#issuecomment-33498647)
# On delete: give time for the crd sm instance to be removed (which depends on running finalizer)
# Cheap for now - replace with polling of specific resources
resource "time_sleep" "wait_operators" {
  depends_on = [helm_release.service_mesh_operator[0]]
  count      = var.deploy_operators == true ? 1 : 0

  create_duration  = local.sleep_create
  destroy_duration = local.sleep_destroy
}

##############################################################################
# Control plane namespace(s)
##############################################################################

resource "kubernetes_namespace" "controlplane_namespace" {
  depends_on = [helm_release.service_mesh_operator[0]]
  for_each   = toset(var.service_mesh_control_planes[*].namespace)

  metadata {
    name = each.key
  }

  timeouts {
    delete = "30m"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

##############################################################################
# Service Mesh Control Plane(s)
##############################################################################

resource "helm_release" "service_mesh_control_plane" {
  depends_on = [time_sleep.wait_operators[0], kubernetes_namespace.controlplane_namespace]

  name              = var.release_name_sm_control_plane
  chart             = "${path.module}/chart/${local.chart_path_sm_control_plane}"
  timeout           = 600
  dependency_update = true
  force_update      = false
  cleanup_on_fail   = false
  wait              = true
  namespace         = var.release_namespace_sm_control_plane

  disable_openapi_validation = false

  values = [yamlencode({
    controlplanes = local.controlplanes_config
  }), local.subnet_values, local.subnet_zone_values]
}

##############################################################################
# Confirm istio operational
##############################################################################

resource "null_resource" "confirm_istio_operational" {
  depends_on = [helm_release.service_mesh_control_plane]
  for_each   = local.plain_filtered_public_ingress_namespaces_list

  provisioner "local-exec" {
    command     = "${path.module}/scripts/confirm-istio-operational.sh \"${each.value.namespace}\" \"${each.value.service}\""
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = data.ibm_container_cluster_config.cluster_config.config_file_path
    }
  }
}

##############################################################################
# Deleting the default route for istio-ingressgateway in all the controlplanes namespaces
# The VPC Load Balancer that is created by the istio-ingressgateway service
# will be used instead of the OpenShift route. The route will not get recreated
# since it is disabled in the servicemesh-control-plane.yaml.
##############################################################################

resource "null_resource" "delete_default_route_istio_ingressgateway" {
  depends_on = [null_resource.confirm_istio_operational]
  for_each   = local.plain_filtered_public_ingress_namespaces_list

  provisioner "local-exec" {
    command     = "${path.module}/scripts/delete-route.sh \"${each.value.namespace}\" \"${each.value.service}\""
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = data.ibm_container_cluster_config.cluster_config.config_file_path
    }
  }
}

##############################################################################
# CSE Proxy
##############################################################################

resource "helm_release" "service_mesh_cse_proxy" {
  depends_on = [null_resource.confirm_istio_operational]

  name              = var.release_name_sm_cse_proxy
  chart             = "${path.module}/chart/${local.chart_path_sm_cse_proxy}"
  timeout           = 600
  dependency_update = true
  force_update      = false
  cleanup_on_fail   = false
  wait              = true
  namespace         = var.release_namespace_sm_cse_proxy

  disable_openapi_validation = false

  values = [yamlencode({
    controlplanes = local.controlplanes_config
  })]
}

##############################################################################
# Ingress Proxy
##############################################################################

resource "helm_release" "service_mesh_ingress_proxy" {
  depends_on = [null_resource.confirm_istio_operational]

  name              = var.release_name_sm_ingress_proxy
  chart             = "${path.module}/chart/${local.chart_path_sm_ingress_proxy}"
  timeout           = 600
  dependency_update = true
  force_update      = false
  cleanup_on_fail   = false
  wait              = true
  namespace         = var.release_namespace_sm_ingress_proxy

  disable_openapi_validation = false

  values = [yamlencode({
    controlplanes = local.controlplanes_config
  })]
}

##############################################################################
# Lookup for default istio-ingressgateway ingress service data in all controlplanes
##############################################################################

data "kubernetes_service" "istio_ingressgateway" {
  depends_on = [null_resource.confirm_istio_operational]
  for_each = {
    for l in local.full_public_ingress_namespaces_list : l.namespace => l if l.publicIngress != null
  }

  metadata {
    name      = each.value.publicIngress
    namespace = each.value.namespace
  }

}

##############################################################################
# Lookup for all the public ingress services data in all controlplanes
##############################################################################

data "kubernetes_service" "all_istio_public_ingress_gateways" {
  depends_on = [null_resource.confirm_istio_operational]
  for_each   = local.plain_filtered_public_ingress_namespaces_list

  metadata {
    name      = each.value.service
    namespace = each.value.namespace
  }
}

##############################################################################
# Confirm all the sdnlb LBs are successfully deployed for all the controlplanes
##############################################################################

resource "null_resource" "confirm_sdnlb_deployed" {
  depends_on = [null_resource.confirm_istio_operational]
  for_each   = { for k, v in local.plain_filtered_sdnlb_namespaces_list : k => v if var.confirm_sdnlb_readiness == true }

  provisioner "local-exec" {
    command     = "/usr/bin/env python3 ${path.module}/scripts/confirm-sdnlb-deployed.py \"${each.value.namespace}\" \"${each.value.service}\""
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = data.ibm_container_cluster_config.cluster_config.config_file_path
    }
  }
}

##############################################################################
# Retrieving sDNLB IPs from the first sDNLB found in the first namespace of filtered_sdnlb_namespaces_list
# Note: This datasource takes care only of first one and is kept as-is to avoid disruption to adopters already using it. All sDNLB IPs are returned through all_sdnlb_loadbalancers
##############################################################################
data "kubernetes_service" "sdnlb_loadbalancer" {
  depends_on = [null_resource.confirm_sdnlb_deployed]
  count      = length(local.filtered_sdnlb_namespaces_list) == 0 || var.confirm_sdnlb_readiness == false ? 0 : 1

  metadata {
    namespace = local.filtered_sdnlb_namespaces_list[0].namespace
    name      = local.filtered_sdnlb_namespaces_list[0].svcs[0]
  }
}

##############################################################################
# Retrieving sDNLB IPs from the every sDNLB LBs found in the plain_filtered_sdnlb_namespaces_list
##############################################################################
data "kubernetes_service" "all_sdnlb_loadbalancers" {
  depends_on = [null_resource.confirm_sdnlb_deployed]
  for_each   = { for k, v in local.plain_filtered_sdnlb_namespaces_list : k => v if var.confirm_sdnlb_readiness == true }

  metadata {
    namespace = each.value.namespace
    name      = each.value.service
  }
}

##############################################################################
# Ingress sub-domains for the default istio-ingressgateway ingress services in all controlplanes
##############################################################################

locals {
  istio_ingressgateway = [for k in data.kubernetes_service.istio_ingressgateway : k]
}

module "ingress_subdomain" {
  source                        = "./modules/ocp-service-mesh-dns-nlb"
  count                         = var.create_ingress_subdomains == true ? length(local.istio_ingressgateway) : 0
  istio_control_plane_namespace = local.istio_ingressgateway[count.index].metadata[0].namespace
  ibmcloud_api_key              = var.ibmcloud_api_key
  cluster_id                    = var.cluster_id
  default_vpc_lb_host           = local.istio_ingressgateway[count.index].status[0].load_balancer[0].ingress[0].hostname
}
