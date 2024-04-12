#!/bin/bash

# ================================= Set environment variables ======================================

# Model and entrypoint configuration. API Server URL (host, port) are set automatically based on the
# SLURM job and are written to the file specified at VLLM_BASE_URL_FILENAME
export MODEL_NAME="Mixtral"
export MODEL_VARIANT="8x7B-Instruct-v0.1"
export MODEL_DIR="$(dirname $(realpath "$0"))"
export VLLM_BASE_URL_FILENAME="${MODEL_DIR}/.vLLM_${MODEL_NAME}-${MODEL_VARIANT}_url"
 
# Variables specific to your working environment, below are examples for the Vector cluster
export VENV_BASE=/projects/aieng/public/mixtral_vllm_env
export VLLM_MODEL_WEIGHTS=/model-weights/Mixtral-${MODEL_VARIANT}
export LD_LIBRARY_PATH="/scratch/ssd001/pkgs/cudnn-11.7-v8.5.0.96/lib/:/scratch/ssd001/pkgs/cuda-11.7/targets/x86_64-linux/lib/"

# Slurm job configuration
export JOB_NAME="vLLM/${MODEL_NAME}-${MODEL_VARIANT}"
export NUM_NODES=1
export NUM_GPUS=4
export JOB_PARTITION="a40"
export QOS="m3"

# ======================================= Optional Settings ========================================

while getopts "p:N:n:q:t:e:v:" flag; do 
    case "${flag}" in
        p) partition=${OPTARG};;
        N) num_nodes=${OPTARG};;
        n) num_gpus=${OPTARG};;
        q) qos=${OPTARG};;
        t) data_type=${OPTARG};;
        e) virtual_env=${OPTARG};;
        v) model_variant=${OPTARG};;
        *) echo "Invalid option: $flag" ;;
    esac
done

if [ -n "$partition" ]; then
    export JOB_PARTITION=$partition
    echo "Partition set to: ${JOB_PARTITION}"
fi

if [ -n "$num_nodes" ]; then
    export NUM_NODES=$num_nodes
    echo "Number of nodes set to: ${NUM_NODES}"
fi

if [ -n "$num_gpus" ]; then
    export NUM_GPUS=$num_gpus
    echo "Number of GPUs set to: ${NUM_GPUS}"
fi

if [ -n "$qos" ]; then
    export QOS=$qos
    echo "QOS set to: ${QOS}"
fi

if [ -n "$data_type" ]; then
    export VLLM_DATA_TYPE=$data_type
    echo "Data type set to: ${VLLM_DATA_TYPE}"
fi

if [ -n "$virtual_env" ]; then
    export VENV_BASE=$virtual_env
    echo "Virtual environment set to: ${VENV_BASE}"
fi

if [ -n "$model_variant" ]; then
    export MODEL_VARIANT=$model_variant
    echo "Model variant set to: ${MODEL_VARIANT}"

    export VLLM_MODEL_WEIGHTS=/model-weights/Mixtral-${MODEL_VARIANT}
    export JOB_NAME="vLLM/${MODEL_NAME}-${MODEL_VARIANT}"
    export VLLM_BASE_URL_FILENAME="$(dirname $(realpath "$0"))/.vLLM_${MODEL_NAME}-${MODEL_VARIANT}_url"
fi

# Set data type to fp16 instead of bf16 for non-Ampere GPUs
fp16_partitions="t4v1 t4v2"

# choose from 'auto', 'half', 'float16', 'bfloat16', 'float', 'float32'
if [[ ${fp16_partitions} =~ ${JOB_PARTITION} ]]; then
    export VLLM_DATA_TYPE="float16"
else
    export VLLM_DATA_TYPE="auto"
fi

# ========================================= Launch Server ==========================================

# Create a file to store the API server URL if it doesn't exist
if [ -f ${VLLM_BASE_URL_FILENAME} ]; then
    touch ${VLLM_BASE_URL_FILENAME}
fi

echo Job Name: ${JOB_NAME}
echo Partition: ${JOB_PARTITION}
echo Generic Resource Scheduling: gpu:$((NUM_NODES*NUM_GPUS))
echo Data Type: ${VLLM_DATA_TYPE}

is_multi=""
if [ "$NUM_NODES" -gt 1 ]; then
    is_multi="multinode_"
fi

sbatch --job-name ${JOB_NAME} \
    --partition ${JOB_PARTITION} \
    --nodes ${NUM_NODES} \
    --gres gpu:${NUM_GPUS} \
    --qos ${QOS} \
    --output ${MODEL_DIR}/vllm-${MODEL_NAME}-${MODEL_VARIANT}.%j.out\
    --error ${MODEL_DIR}/vllm-${MODEL_NAME}-${MODEL_VARIANT}.%j.err\
    $(dirname ${MODEL_DIR})/${is_multi}vllm.slurm
