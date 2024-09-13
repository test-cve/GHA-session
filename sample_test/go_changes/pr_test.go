package test

import (
	"log"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"gopkg.in/yaml.v3"
)

const sdnlbExample = "examples/alb-public-ingress-egress-with-sdnlb-transit"
const nlbNoTransitExample = "examples/nlb-public-ingress-egress-no-transit"

const resourceGroup = "geretain-test-ocp-service-mesh"

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

// test config parameters
type Config struct {
	SdnlbServiceidName string `yaml:"sdnlbServiceIdName"`
}

var sdnlbServiceIdName string

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {
	// Read the YAML file contents
	data, err := os.ReadFile(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}
	// Create a struct to hold the YAML data
	var config Config
	// Unmarshal the YAML data into the struct
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		log.Fatal(err)
	}
	// Parse the sdnlbServiceIdName to use in the test
	sdnlbServiceIdName = config.SdnlbServiceidName
	err = log.Output(1, "TestMain using sdnlbServiceIdName "+sdnlbServiceIdName)
	if err != nil {
		log.Fatal(err)
	}
	os.Exit(m.Run())
}

func setupOptions(t *testing.T, prefix string, exampleDir string, implicitDestroy []string, terraformVars map[string]interface{}) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:       t,
		TerraformDir:  exampleDir,
		Prefix:        prefix,
		ResourceGroup: resourceGroup,
		IgnoreDestroys: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				"module.cluster_proxy.helm_release.cluster_proxy_config",
				"module.cluster_proxy.null_resource.configure_proxy",
				"module.ocp_all_inclusive.module.ocp_console_patch.null_resource.patch_console_pods",
				"module.ocp_all_inclusive.module.cluster_proxy.null_resource.configure_proxy",
				// resources below can be removed once PR https://github.ibm.com/GoldenEye/ocp-service-mesh-module/pull/733 is merged
				"module.service_mesh.null_resource.delete_default_route_istio_ingressgateway[\"istio-system\"]",
				"module.service_mesh.null_resource.confirm_sdnlb_deployed[0]",
				"module.service_mesh.null_resource.confirm_istio_operational[\"istio-system\"]",
			},
		},
		IgnoreUpdates: testhelper.Exemptions{ // Ignore for consistency check
			List: []string{
				"module.cluster_proxy.helm_release.cluster_proxy_config",
				"module.cluster_proxy.null_resource.configure_proxy",
				"module.cluster_proxy.helm_release.cluster_proxy",
				"module.service_mesh.helm_release.service_mesh_cse_proxy",
				"module.service_mesh.helm_release.service_mesh_control_plane",
				"module.ocp_all_inclusive.module.cluster_proxy.helm_release.cluster_proxy",
				"module.ocp_all_inclusive.module.cluster_proxy.helm_release.cluster_proxy_config",
				"module.ocp_all_inclusive.module.service_mesh[0].helm_release.service_mesh_cse_proxy",
				"module.ocp_all_inclusive.module.service_mesh[0].helm_release.service_mesh_control_plane",
				// to remove once https://github.ibm.com/GoldenEye/ocp-service-mesh-module/pull/738 is merged
				"module.service_mesh.helm_release.service_mesh_operator[0]",
			},
		},
		TerraformVars:    terraformVars,
		ImplicitDestroy:  implicitDestroy,
		ImplicitRequired: false,
	})

	return options
}

func TestRunSdnlbExample(t *testing.T) {
	t.Parallel()

	// expected label to use for the istio ingress gateway selectors
	istioIngressGwLabel := "svc-mesh-sdnlb-gw"

	implicitDestroy := []string{ // Ignore full destroy to speed up tests
		"kubernetes_namespace.bookinfo",
		"helm_release.bookinfo",
		"helm_release.egress_test",
		"module.cluster_proxy",
		"module.ocp_base.ibm_container_vpc_worker_pool.pool",
		"module.ocp_base.null_resource.confirm_network_healthy",
	}

	extTerraformVars := map[string]interface{}{
		"existing_sdnlb_serviceid_name": sdnlbServiceIdName,
		"sm_label":                      istioIngressGwLabel,
	}

	options := setupOptions(t, "svc-mesh-sdnlb", sdnlbExample, implicitDestroy, extTerraformVars)

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")

}

func TestRunNlbNoTransitExample(t *testing.T) {
	t.Parallel()

	implicitDestroy := []string{ // Ignore full destroy to speed up tests
		"kubernetes_namespace.bookinfo",
		"helm_release.bookinfo",
		"module.cluster_proxy",
		"module.ocp_base.ibm_container_vpc_worker_pool.pool",
		"module.ocp_base.null_resource.confirm_network_healthy",
	}

	options := setupOptions(t, "svc-mesh-nlb", nlbNoTransitExample, implicitDestroy, nil)

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunUpgradeExample(t *testing.T) {
	t.Parallel()

	implicitDestroy := []string{ // Ignore full destroy to speed up tests
		"kubernetes_namespace.bookinfo",
		"helm_release.bookinfo",
		"helm_release.egress_test",
		"module.cluster_proxy",
		"module.ocp_base.ibm_container_vpc_worker_pool.pool",
		"module.ocp_base.null_resource.confirm_network_healthy",
	}

	extTerraformVars := map[string]interface{}{
		"existing_sdnlb_serviceid_name": sdnlbServiceIdName,
	}

	options := setupOptions(t, "svc-mesh-upg", sdnlbExample, implicitDestroy, extTerraformVars)

	output, err := options.RunTestUpgrade()

	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}
