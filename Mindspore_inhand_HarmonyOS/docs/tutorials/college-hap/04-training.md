---
id: training
step: "04"
title: 训练五轮，看准确率爬坡
---

# 训练五轮，看准确率爬坡

## 这一节要做什么

训练 5 轮，每轮结束在 10,000 张测试图上算一次准确率。

## 正文

训练配置：batch size 32，Momentum 优化器（学习率 0.01，动量 0.9），跑在 CPU 上。脚本用 `ms.set_context(mode=ms.GRAPH_MODE)` 开静态图模式，CPU 上训练更快。每轮训练完立刻评估一次：

```text
for epoch in range(1, 6):
    model.train(1, train_data, dataset_sink_mode=False)
    metrics = model.eval(test_data, dataset_sink_mode=False)
    print(epoch, metrics["accuracy"])
```

真实运行日志如下，第一轮就有 98.08%，第四轮达到最高的 98.87%：

```text
epoch=01 test_accuracy=0.9808 seconds=9.347
epoch=02 test_accuracy=0.9848 seconds=7.383
epoch=03 test_accuracy=0.9852 seconds=9.380
epoch=04 test_accuracy=0.9887 seconds=12.199
epoch=05 test_accuracy=0.9882 seconds=7.726
final_accuracy=0.9882 best_accuracy=0.9887 total_seconds=46.035
```

## 跑出来的结果

五轮训练完成，最终测试准确率 98.82%，最好 98.87%，总耗时 46.035 秒。10,000 张测试图里认错约 112 张。
