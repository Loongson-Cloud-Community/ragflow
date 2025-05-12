#docker build -t cr.loongnix.cn/infiniflow/ragflow:0.17.2  -f Dockerfile .
docker run -it --rm -v $PWD:/ragflow --name down_hugging cr.loongnix.cn/pypa/manylinux_2_28_loongarch64 bash -c "cd /ragflow/ && bash down_ci.sh"
#docker cp down_hugging:/huggingface.co/ ./ && docker rm -f down_hugging
docker build -f Dockerfile.deps -t loongarch64/ragflow_deps_abi1 .
docker buildx build --build-arg LIGHTEN=1 --build-arg NEED_MIRROR=1 -f Dockerfile -t  cr.loongnix.cn/infiniflow/ragflow:0.17.2 .
