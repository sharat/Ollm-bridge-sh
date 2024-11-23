#!/bin/bash
set -euo pipefail

# Ollm Bridge v 0.6
# Ollm Bridge aims to create a structure of directories and symlinks to make Ollama models more easily accessible to LMStudio users.

# Define the directory variables
manifest_dir="$HOME/.ollama/models/manifests/registry.ollama.ai"
blob_dir="$HOME/.ollama/models/blobs"
publicModels_dir="$HOME/publicmodels"

# Print the base directories to confirm the variables
echo ""
echo "Confirming Directories:"
echo ""
echo "Manifest Directory: $manifest_dir"
echo "Blob Directory: $blob_dir"
echo "Public Models Directory: $publicModels_dir"

# Check if the $publicModels_dir/lmstudio directory already exists, and delete it if so
if [ -d "$publicModels_dir/lmstudio" ]; then
    echo ""
    rm -rf "$publicModels_dir/lmstudio"
    echo "Ollm Bridge Directory Reset."
fi

if [ -d "$publicModels_dir" ]; then
    echo ""
    echo "Public Models Directory Confirmed."
else
    mkdir -p "$publicModels_dir"
    echo ""
    echo "Public Models Directory Created."
fi

# Explore the manifest directory and record the manifest file locations
echo ""
echo "Exploring Manifest Directory:"
echo ""

# Find all manifest files
manifestLocations=$(find "$manifest_dir" -type f)

echo ""
echo "File Locations:"
echo ""
for manifest in $manifestLocations; do
    echo "$manifest"
done

# Parse through JSON files to get model info
for manifest in $manifestLocations; do
    json=$(cat "$manifest")

    # Check if 'config.digest' exists
    digest=$(echo "$json" | jq -r '.config.digest // empty')

    if [ -n "$digest" ]; then
        # Replace "sha256:" with "sha256-" in the config digest
        digest_sanitized=$(echo "$digest" | sed 's/sha256://')
        modelConfig="$blob_dir/sha256-$digest_sanitized"
    else
        echo "No 'config.digest' found in $manifest, skipping."
        continue
    fi

    # Initialize variables
    unset modelFile
    unset modelTemplate
    unset modelParams

    # Iterate over layers
    layers=$(echo "$json" | jq -c '.layers[]')
    for layer_json in $layers; do
        mediaType=$(echo "$layer_json" | jq -r '.mediaType')
        layer_digest=$(echo "$layer_json" | jq -r '.digest')
        digest_sanitized=$(echo "$layer_digest" | sed 's/sha256://')
        if [[ "$mediaType" == *"model" ]]; then
            modelFile="$blob_dir/sha256-$digest_sanitized"
        elif [[ "$mediaType" == *"template" ]]; then
            modelTemplate="$blob_dir/sha256-$digest_sanitized"
        elif [[ "$mediaType" == *"params" ]]; then
            modelParams="$blob_dir/sha256-$digest_sanitized"
        fi
    done

    # Extract variables from $modelConfig
    if [ -f "$modelConfig" ]; then
        modelConfigObj=$(cat "$modelConfig")
        modelQuant=$(echo "$modelConfigObj" | jq -r '.file_type // empty')
        modelExt=$(echo "$modelConfigObj" | jq -r '.model_format // empty')
        modelTrainedOn=$(echo "$modelConfigObj" | jq -r '.model_type // empty')
    else
        echo "Model config file $modelConfig does not exist, skipping."
        continue
    fi

    # Ensure variables are set
    if [ -z "$modelQuant" ] || [ -z "$modelExt" ] || [ -z "$modelTrainedOn" ]; then
        echo "Missing model configuration details for $manifest, skipping."
        continue
    fi

    # Get the parent directory of $manifest
    parentDir=$(dirname "$manifest")
    modelName=$(basename "$parentDir")

    echo ""
    echo "Model Name is $modelName"
    echo "Quant is $modelQuant"
    echo "Extension is $modelExt"
    echo "Number of Parameters Trained on is $modelTrainedOn"
    echo ""

    # Check if the lmstudio directory exists and create if necessary
    if [ ! -d "$publicModels_dir/lmstudio" ]; then
        echo ""
        echo "Creating lmstudio directory..."
        mkdir -p "$publicModels_dir/lmstudio"
    fi

    # Check if the subdirectory exists and create if necessary
    if [ ! -d "$publicModels_dir/lmstudio/$modelName" ]; then
        echo ""
        echo "Creating $modelName directory..."
        mkdir -p "$publicModels_dir/lmstudio/$modelName"
    fi

    # Check if modelFile exists
    if [ -f "$modelFile" ]; then
        # Create the symbolic link
        echo ""
        echo "Creating symbolic link for $modelFile..."
        ln -sf "$modelFile" "$publicModels_dir/lmstudio/$modelName/${modelName}-${modelTrainedOn}-${modelQuant}.${modelExt}"
    else
        echo "Model file $modelFile does not exist, skipping."
    fi
done

echo ""
echo ""
echo "*********************"
echo "Ollm Bridge complete."
echo "Set the Models Directory in LMStudio to $publicModels_dir/lmstudio"
