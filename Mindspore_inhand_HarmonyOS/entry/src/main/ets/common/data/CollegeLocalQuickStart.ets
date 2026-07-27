import { CollegeItem, collegeItems } from './CollegeCatalog';

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
    title: '实验目标与环境',
    objective: '用 MindSpore 在本机完整复现“卷积网络识别手写数字”的经典入门流程。',
    paragraphs: [
      '本教程不是一段概念介绍，而是已经在本机执行过的训练、评估和导出记录。环境为 Windows 11、Python 3.11.7、MindSpore 2.5.0（CPU）、scikit-learn 1.3.2、NumPy 1.26.4 和 Pillow 12.1.1。',
      '本机没有缓存真实 MNIST 的 IDX 文件。为了保持完全离线，实验改用 scikit-learn 自带的 digits：1797 张 8×8 灰度手写数字图。它复现了 PyTorch 初学教程的任务结构，但后文准确率只代表 digits 测试集，不能写成 MNIST 准确率。',
      'PyTorch 2.6.0 本体可用，但本机 torchvision 0.22.0 与它不匹配，导入时报告 operator torchvision::nms does not exist。因此数据读取不依赖 torchvision，也不需要联网。'
    ],
    codeBlocks: [
      {
        title: '环境检查',
        code: 'python --version\npython -m pip show mindspore torch torchvision scikit-learn numpy pillow\npython -c "import mindspore as ms; print(ms.__version__, ms.get_context(\'device_target\'))"'
      },
      {
        title: '完整复现命令',
        code: 'python docs/tutorials/mindspore-digits-lenet.py --epochs 20 --batch-size 64 --learning-rate 0.002 --output-dir .tmp-college-tutorial/verified-artifacts'
      }
    ],
    measuredResult: '实测环境识别为 Python 3.11.7、MindSpore 2.5.0、CPU。训练脚本、参数和完整记录已保存在项目 docs/tutorials 目录，可离线重新执行。'
  },
  {
    id: 'data',
    step: '02',
    title: '准备本地数据',
    objective: '把内置 8×8 手写数字转换为 LeNet 可用的 float32 NCHW 张量，并建立可重复的数据切分。',
    paragraphs: [
      'load_digits() 返回 1797 张图片，像素范围是 0–16，标签为 0–9。脚本先映射到 8-bit 灰度，再用 Pillow 双线性插值放大为 28×28，最后用 (x - 0.5) / 0.5 归一化到 [-1, 1]。',
      '模型输入形状为 [N, 1, 28, 28]，数据类型 float32；标签类型 int32。按标签分层进行 80/20 切分，随机种子固定为 42，得到 1437 张训练图片和 360 张测试图片。',
      'MindSpore 的 NumpySlicesDataset 接收内存数组，batch(64) 生成批次。训练集开启 shuffle，测试集关闭 shuffle，且两者都保留最后一个不足 64 的批次。'
    ],
    codeBlocks: [
      {
        title: '缩放与归一化',
        code: 'pixels = np.rint(image / 16.0 * 255.0).astype(np.uint8)\ncanvas = Image.fromarray(pixels, mode="L").resize((28, 28), Image.Resampling.BILINEAR)\nnormalized = np.asarray(canvas, dtype=np.float32) / 255.0\ninput_tensor = ((normalized - 0.5) / 0.5)[None, :, :]'
      },
      {
        title: '切分与批处理',
        code: 'train_x, test_x, train_y, test_y = train_test_split(\n    images, labels, test_size=0.2, random_state=42, stratify=labels\n)\ntrain_data = ds.NumpySlicesDataset(\n    {"image": train_x, "label": train_y.astype(np.int32)}, shuffle=True\n).batch(64, drop_remainder=False)'
      }
    ],
    measuredResult: '实测原始形状 [1797, 8, 8]，处理后形状 [1797, 1, 28, 28]；训练 1437 张、测试 360 张，数据全程来自本地安装包。'
  },
  {
    id: 'network',
    step: '03',
    title: '构建 LeNet 风格网络',
    objective: '理解 PyTorch 入门写法与 MindSpore 的一一对应关系，并搭建 10 类分类网络。',
    paragraphs: [
      '网络使用两组“卷积—ReLU—最大池化”提取特征，再通过 120、84 和 10 个神经元的全连接层输出十类 logits，共 44,404 个可训练参数。',
      'PyTorch 的 nn.Module 对应 MindSpore 的 nn.Cell，forward() 对应 construct()；DataLoader 对应 mindspore.dataset 与 batch()；CrossEntropyLoss 对应 sparse=True 的 SoftmaxCrossEntropyWithLogits；torch.optim.Adam 对应 nn.Adam。',
      '这是采用 ReLU 与 MaxPool 的现代 LeNet-5 风格实现，用来讲清卷积分类流程，不宣称逐层复刻 1998 年原始网络。'
    ],
    codeBlocks: [
      {
        title: 'MindSpore 网络',
        code: 'class LeNet5(nn.Cell):\n    def __init__(self):\n        super().__init__()\n        self.features = nn.SequentialCell(\n            nn.Conv2d(1, 6, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2),\n            nn.Conv2d(6, 16, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2)\n        )\n        self.classifier = nn.SequentialCell(\n            nn.Flatten(), nn.Dense(16 * 4 * 4, 120), nn.ReLU(),\n            nn.Dense(120, 84), nn.ReLU(), nn.Dense(84, 10)\n        )\n\n    def construct(self, x):\n        return self.classifier(self.features(x))'
      },
      {
        title: '损失与优化器',
        code: 'loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")\noptimizer = nn.Adam(network.trainable_params(), learning_rate=0.002)\nmodel = ms.Model(network, loss_fn=loss_fn, optimizer=optimizer,\n                 metrics={"accuracy": nn.Accuracy()})'
      }
    ],
    measuredResult: '网络在 MindSpore 2.5.0 CPU 下成功完成前向、反向和参数更新；唯一输入为 float32 NCHW [N,1,28,28]，输出为 float32 [N,10]。'
  },
  {
    id: 'training',
    step: '04',
    title: '训练并读懂结果',
    objective: '运行 20 轮训练，逐轮在独立测试集评估，并正确理解准确率与波动。',
    paragraphs: [
      '训练参数为 batch size 64、Adam、学习率 0.002、20 epochs，dataset_sink_mode=False。每轮训练结束后立即对 360 张测试图片计算 accuracy。',
      '首次完整运行从第 1 轮的 80.28% 上升到第 20 轮的 98.61%，最终/最佳均为 98.61%，训练耗时 4.344 秒。脚本移入文档目录后的验证重跑最终 96.94%、最佳 98.33%，训练耗时 4.497 秒。',
      '两次都超过 96%，但 CPU 算子仍会产生轻微运行差异。教程保留两次真实结果，不把某一次最高准确率当作保证值，也不把 digits 的结果外推到标准 MNIST。'
    ],
    codeBlocks: [
      {
        title: '训练与评估循环',
        code: 'for epoch in range(1, 21):\n    model.train(1, train_data, dataset_sink_mode=False)\n    metrics = model.eval(test_data, dataset_sink_mode=False)\n    print(epoch, metrics["accuracy"])'
      },
      {
        title: '首次完整运行日志',
        code: 'epoch=01 test_accuracy=0.8028 seconds=0.348\nepoch=06 test_accuracy=0.9667 seconds=0.212\nepoch=14 test_accuracy=0.9833 seconds=0.208\nepoch=20 test_accuracy=0.9861 seconds=0.199'
      }
    ],
    measuredResult: '首次运行：最终/最佳 98.61%，训练 4.344 秒；正式脚本验证重跑：最终 96.94%、最佳 98.33%，训练 4.497 秒。两次均完成 20 轮且无数据下载。'
  },
  {
    id: 'export',
    step: '05',
    title: '导出模型与端侧边界',
    objective: '保存 checkpoint、导出 MindIR、验证回载一致性，并区分桌面 MindIR 与 HarmonyOS Lite 模型。',
    paragraphs: [
      '训练后保存 lenet_digits.ckpt，并用全零 [1,1,28,28] float32 张量固定导出输入契约。MindIR 图在回载执行时必须切换到 GRAPH_MODE；第一次保留在 PYNATIVE_MODE 会得到明确错误，切换后成功。',
      '固定测试样本真实标签为 5，训练网络预测 5，MindIR 回载后也预测 5；两份 logits 最大绝对差为 0.0，说明本次桌面导出未改变该样本的数值结果。',
      '当前 HarmonyOS 应用加载的是 MindSpore Lite .ms，现有自定义模型入口要求 float32 NHWC [1,224,224,3]。本教程的桌面 MindIR 是 float32 NCHW [1,1,28,28]，格式和张量契约均不匹配，不能直接导入，更不能只改扩展名。',
      '仓库和 PATH 中没有 converter_lite，所以本次没有宣称完成 .ms 转换、API 24 模拟器加载或 arm64 真机推理。真正接入需要先转换 MINDIR_LITE，再实现完全相同的灰度化、缩放、归一化和 NCHW 排列，并用同一批样本做数值一致性验证。'
    ],
    codeBlocks: [
      {
        title: '保存与导出',
        code: 'ms.save_checkpoint(network, "lenet_digits.ckpt")\nms.export(network, Tensor(np.zeros((1, 1, 28, 28), np.float32)),\n          file_name="lenet_digits", file_format="MINDIR")'
      },
      {
        title: '回载验证',
        code: 'ms.set_context(mode=ms.GRAPH_MODE)\ngraph_network = nn.GraphCell(ms.load("lenet_digits.mindir"))\nexported_logits = graph_network(Tensor(test_x[:1])).asnumpy()'
      }
    ],
    measuredResult: '实测 CKPT 177,956 B、MindIR 188,389 B；样本标签/导出前预测/回载后预测均为 5，logits 最大差 0.0。Lite .ms 转换与 HarmonyOS 端侧推理尚未执行，页面明确标注该边界。'
  }
];

export function nextCollegeQuickStartExpandedId(currentId: string, selectedId: string): string {
  return currentId === selectedId ? '' : selectedId;
}
