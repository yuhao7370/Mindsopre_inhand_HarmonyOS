---
id: training
step: "04"
title: 跑训练，看结果
---

# 跑训练，看结果

## 这一节要做什么

训练 20 轮，每轮都看一次测试准确率，再比较两次运行为什么会有小幅波动。

## 正文

设置很简单：batch size 64，优化器用 Adam，学习率 0.002，一共训练 20 轮，dataset_sink_mode=False。每轮结束后，马上用 360 张测试图算一次准确率。

第一次运行从第 1 轮的 80.28% 涨到第 20 轮的 98.61%，最终和最好成绩都是 98.61%，训练用了 4.344 秒。把脚本移到文档目录后又跑了一遍，最终是 96.94%，最好是 98.33%，耗时 4.497 秒。

两次结果都过了 96%，但并不完全相同。CPU 算子的细微差异会带来这种波动，所以看趋势比盯着某个最高值更有意义。别忘了，这些数字只对应 digits 测试集。

### 训练与评估循环

```text
for epoch in range(1, 21):
    model.train(1, train_data, dataset_sink_mode=False)
    metrics = model.eval(test_data, dataset_sink_mode=False)
    print(epoch, metrics["accuracy"])
```

### 第一次运行的日志

```text
epoch=01 test_accuracy=0.8028 seconds=0.348
epoch=06 test_accuracy=0.9667 seconds=0.212
epoch=14 test_accuracy=0.9833 seconds=0.208
epoch=20 test_accuracy=0.9861 seconds=0.199
```

## 跑出来的结果

第一次跑到 98.61%，用了 4.344 秒；重跑最终 96.94%、最好 98.33%，用了 4.497 秒。两次都完成了 20 轮，也都没有下载数据。
