# iOS富文本笔记

作为我的iOS入门项目，只实现了非常简单的富文本功能。
实现了以下组件：
- 核心富文本编辑器：
  - 业务逻辑样式标记（与实际渲染独立、利于序列/反序列）
  - 编辑逻辑
  - 和UI无关，方便进行单元测试
- 富文本渲染器
  - 根据业务逻辑样式标记渲染最终的富文本效果（使用视觉样式标记实现）
  - 和UI无关，方便进行单元测试
- 富文本附件view
  - 自定义的附件view（iOS15的TextKit已提供官方支持），支持在textview中预留对应的附件区域，
    而实际的附件内容在textview之上显示
  - 可以实现复杂UI/UX的富文本内容，比如表格、视频
- NotesView
  - 布局管理textview、附件view
  - 监听、过滤修改textview输入，和富文本编辑器配合完成编辑
  - 根据业务逻辑修改默认的NSLayoutManager行为
  - 统筹附件、textview输入
- NotesDetailViewController
  - 笔记详情页的控制器
  - 管理内容输入和菜单
- 其它
  - 因为低版本的iOS低版本中，底部弹窗不支持设置自定义大小，我自己实现了一个BottomSheetPresentationController，但是自定义的底部弹窗控制器也有一些缺陷，比如显示弹窗时会使编辑器的光标消失，需要在显示弹窗前先设置不一样的光标位置再设置回来进行workaround，而官方提供的UISheetPresentationController则可以直接通过设置undimmed设置穿透事件且光标不会消失，但是这其实使用了私有的UITransitionView的\_ignoreDirectTouchEvents，我们在不借助private api的情况下无法使用

## 演示
![演示动图](notes.gif)

[演示视频](notes.mp4)

