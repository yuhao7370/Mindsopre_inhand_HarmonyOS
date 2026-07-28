---
id: environment
step: "01"
title: 准备环境和数据集
---

# 准备环境和数据集

## 这一节要做什么

装好一个能跑 MindSpore 的 Python 环境，再把 MNIST 数据集下载到本地。

## 正文

新建一个 Python 3.11.15 环境，然后在里面 `pip install mindspore`，装到的是 MindSpore 2.9.0（CPU 版），附带 NumPy 1.26.4 和 Pillow 12.3.0。

```text
micromamba create -n ms python=3.11 -c conda-forge
micromamba run -n ms pip install mindspore
```

装完后跑一条命令确认 MindSpore 能正常导入：

```text
python -c "import mindspore as ms; print(ms.__version__)"
```

接下来是数据集。MNIST 是手写数字识别的"Hello World"：60,000 张训练图、10,000 张测试图，每张是 28×28 的灰度图，标签是 0 到 9。文件链接如下：

```text
https://ossci-datasets.s3.amazonaws.com/mnist/train-images-idx3-ubyte.gz
https://ossci-datasets.s3.amazonaws.com/mnist/train-labels-idx1-ubyte.gz
https://ossci-datasets.s3.amazonaws.com/mnist/t10k-images-idx3-ubyte.gz
https://ossci-datasets.s3.amazonaws.com/mnist/t10k-labels-idx1-ubyte.gz
```

下载后把四个 `.gz` 解压成 IDX 文件，放进 `data/MNIST/` 目录。

## 跑出来的结果

环境就绪：Python 3.11.15 + MindSpore 2.9.0，跑在 CPU 上。MNIST 四个 IDX 文件已就位在 `data/MNIST/`，共 60,000 张训练图和 10,000 张测试图，后续所有实验都从本地读取。
