import { CollegeItem, collegeItems } from './CollegeCatalog';

export const collegeTutorialRawFileName: string = 'college/college-hap.zip';
export const collegeTutorialExportFileName: string = 'MindSpore-MNIST-鍏ラ棬鏁欑▼.zip';

export interface CollegeTutorialCodeBlock {
  readonly title: string;
  readonly code: string;
}

export interface CollegeLocalQuickStartSection {
  readonly id: string;
  readonly step: string;
  readonly title: string;
  readonly objective: string;
  readonly paragraphs: Array<string>;
  readonly codeBlocks: Array<CollegeTutorialCodeBlock>;
  readonly measuredResult: string;
}

export const visibleCollegeItems: CollegeItem[] =
  collegeItems.filter((item: CollegeItem) => item.id !== 'quick' && item.id !== 'faq');

export const collegeLocalQuickStartSections: Array<CollegeLocalQuickStartSection> = [
  {
    id: 'environment',
    step: '01',
    title: '准备环境和数据集',
    objective: '确认运行环境，并了解随教程导出的本地 MNIST 数据。',
    paragraphs: [
      '这套示例使用 Python 3.11.15 和 MindSpore 2.9.0 CPU 版。完整数据、脚本和模型产物都随教程包提供，导出后可离线查看和复现。',
      'MNIST 包含 60,000 张训练图和 10,000 张测试图，每张都是 28×28 灰度图，标签范围为 0 到 9。'
    ],
    codeBlocks: [
      {
        title: '确认环境',
        code: 'python --version\npython -c "import mindspore as ms; print(ms.__version__)"'
      },
      {
        title: '查看本地数据',
        code: 'data/MNIST/train-images-idx3-ubyte\ndata/MNIST/t10k-images-idx3-ubyte'
      }
    ],
    measuredResult: '环境记录为 Python 3.11.15 + MindSpore 2.9.0（CPU），本地 IDX 数据已包含在导出的教程包内。'
  },
  {
    id: 'data',
    step: '02',
    title: '读懂 MNIST，喂给模型',
    objective: '用 MindSpore 数据管道读取 IDX 文件、完成预处理并组 batch。',
    paragraphs: [
      '训练集有 60,000 张图，测试集有 10,000 张图。图片依次经过 Rescale、Normalize(0.1307, 0.3081) 和 HWC2CHW，标签转为 int32。',
      '训练数据会打乱，测试数据保持顺序；batch size 32，最后不足 32 的一批也保留。'
    ],
    codeBlocks: [
      {
        title: '数据管道',
        code: 'dataset = ds.MnistDataset(data_dir, usage=usage, shuffle=shuffle)\ndataset = dataset.map(vision.Rescale(1.0 / 255.0, 0), input_columns="image")\ndataset = dataset.map(vision.Normalize(mean=[0.1307], std=[0.3081]), input_columns="image")\ndataset = dataset.map(vision.HWC2CHW(), input_columns="image")\nreturn dataset.batch(32, drop_remainder=False)'
      }
    ],
    measuredResult: '训练集每轮有 1,875 个 batch，测试集有 313 个；模型输入为 float32 [32, 1, 28, 28]。'
  },
  {
    id: 'network',
    step: '03',
    title: '搭一个 LeNet-5 网络',
    objective: '建立 LeNet-5 风格的卷积网络，完成十分类。',
    paragraphs: [
      '网络使用两组卷积、ReLU 和最大池化，再接 120、84、10 三层全连接；它共有 44,404 个可训练参数。',
      '输入为 float32 [N, 1, 28, 28]，输出为 float32 [N, 10]，最大 logits 对应预测类别。'
    ],
    codeBlocks: [
      {
        title: '损失和优化器',
        code: 'loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")\noptimizer = nn.Momentum(network.trainable_params(), learning_rate=0.01, momentum=0.9)\nmodel = ms.Model(network, loss_fn=loss_fn, optimizer=optimizer, metrics={"accuracy": nn.Accuracy()})'
      }
    ],
    measuredResult: 'LeNet-5 风格网络已在 MindSpore 2.9.0 CPU 环境构建完成，参数总数为 44,404。'
  },
  {
    id: 'training',
    step: '04',
    title: '训练五轮，看准确率爬坡',
    objective: '训练 5 轮，每轮结束后都在完整测试集上评估。',
    paragraphs: [
      '训练采用 batch size 32、Momentum（学习率 0.01，动量 0.9）和 GRAPH_MODE。每轮结束立即调用 model.eval 评估。',
      '真实日志从第一轮的 98.08% 开始，第四轮达到最高准确率；所有指标来自本地 CPU 实测。'
    ],
    codeBlocks: [
      {
        title: '训练循环',
        code: 'for epoch in range(1, 6):\n    model.train(1, train_data, dataset_sink_mode=False)\n    metrics = model.eval(test_data, dataset_sink_mode=False)\n    print(epoch, metrics["accuracy"])'
      },
      {
        title: '最终日志',
        code: 'epoch=04 test_accuracy=0.9887 seconds=12.199\nepoch=05 test_accuracy=0.9882 seconds=7.726\nfinal_accuracy=0.9882 best_accuracy=0.9887 total_seconds=46.035'
      }
    ],
    measuredResult: '5 轮训练完成：最终准确率 98.82%，最佳准确率 98.87%，总耗时 46.035 秒。'
  },
  {
    id: 'export',
    step: '05',
    title: '导出模型，走向 HarmonyOS',
    objective: '保存 CKPT、导出 MindIR，再回载验证计算结果。',
    paragraphs: [
      '训练后先保存权重，再把完整计算图导出为 MindIR。导出和回载都使用同样的 [1, 1, 28, 28] 输入形状，并在 GRAPH_MODE 下验证。',
      '如需完整脚本、IDX 数据和模型文件，请导出随应用附带的教程包；端侧接入前仍需用 converter_lite 转换并保持预处理一致。'
    ],
    codeBlocks: [
      {
        title: '保存与导出',
        code: 'ms.save_checkpoint(network, "lenet_mnist.ckpt")\nms.export(network, Tensor(np.zeros((1, 1, 28, 28), np.float32)),\n          file_name="lenet_mnist", file_format="MINDIR")'
      },
      {
        title: '回载验证',
        code: 'graph_network = nn.GraphCell(ms.load("lenet_mnist.mindir"))\nlogits_export = graph_network(Tensor(image)).asnumpy()'
      }
    ],
    measuredResult: 'lenet_mnist.ckpt 为 177,956 B，lenet_mnist.mindir 为 189,495 B；标签和预测均为 7，logits 最大绝对差为 0.0。'
  }
];

export function nextCollegeQuickStartExpandedId(currentId: string, selectedId: string): string {
  return currentId === selectedId ? '' : selectedId;
}
