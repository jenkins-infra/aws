package tests

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTerraformEksCluster(t *testing.T) {

	// Construct the terraform options with default retryable errors to handle the most common
	// retryable errors in terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Set the path to the Terraform code that will be tested.
		TerraformDir: "../",
	})

	// Retrieve the current workspace
	originalWorkspace, err := terraform.RunTerraformCommandAndGetStdoutE(t, terraformOptions, "workspace", "show")
	if err != nil || originalWorkspace == "" {
		originalWorkspace = "default"
	}

	logger.Terratest.Logf(t, "Original Workspace: %s", originalWorkspace)

	// Generate a random name for this test
	uniqueId := random.UniqueId()
	workpaceName := fmt.Sprintf("terratest-%s", uniqueId)

	// Revert workspace to initial status
	defer func() {
		// Clean up resources
		terraform.Destroy(t, terraformOptions)
		// Switch back to the original workspace
		terraform.WorkspaceSelectOrNew(t, terraformOptions, originalWorkspace)

		// Cleanup the temporary workspace
		terraform.RunTerraformCommand(t, terraformOptions, "workspace", "delete", workpaceName)
	}()

	// Switch to a new temporary workspace
	terraform.WorkspaceSelectOrNew(t, terraformOptions, workpaceName)

	// Run "terraform init" and "terraform plan". Fail the test if there are any errors.
	terraform.InitAndPlan(t, terraformOptions)
}
