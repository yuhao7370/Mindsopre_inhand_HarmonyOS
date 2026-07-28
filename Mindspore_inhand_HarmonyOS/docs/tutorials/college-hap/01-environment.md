---
id: environment
step: "01"
title: 先看任务和环境
---

# 先看任务和环境

## 这一节要做什么

先确认这台电脑能跑什么，再用 MindSpore 做一遍经典的手写数字识别。

## 正文

这套流程已经在本机跑过一遍：训练、评估和导出都留下了实际结果。电脑是 Windows 11，装有 Python 3.11.7、MindSpore 2.5.0（CPU）、scikit-learn 1.3.2、NumPy 1.26.4 和 Pillow 12.1.1。

本机没有真实 MNIST 的 IDX 文件。为了离线也能跑，我们换成 scikit-learn 自带的 digits：1797 张 8×8 灰度手写数字图。任务还是识别 0 到 9，不过后面看到的准确率只属于 digits，不是 MNIST。

PyTorch 2.6.0 本身能用，torchvision 0.22.0 却和它对不上，导入时会报 operator torchvision::nms does not exist。问题出在环境版本，不在 MindSpore。这里直接从 scikit-learn 读数据，也省掉了下载。

### 环境检查

```text
python --version
python -m pip show mindspore torch torchvision scikit-learn numpy pillow
python -c "import mindspore as ms; print(ms.__version__, ms.get_context('device_target'))"
```

### 从头跑一遍

```text
python docs/tutorials/mindspore-digits-lenet.py --epochs 20 --batch-size 64 --learning-rate 0.002 --output-dir .tmp-college-tutorial/verified-artifacts
```

## 跑出来的结果

环境是 Python 3.11.7、MindSpore 2.5.0，跑在 CPU 上。脚本和运行记录都放在 docs/tutorials 目录，断网也能重新执行。
