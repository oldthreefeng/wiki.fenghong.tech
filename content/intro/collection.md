---
title: "Collection"
date: 2018-11-08 16:48
collection:  Simiki
---
## 三层结构

*(1.6.0版本引入)*

Simiki使用三层结构模式来管理个人文档目录(content目录)：

1. 目录(category)：第一层结构，按文件夹存放，用于初步的分类。比如Linux、Python、工具等等。
2. 集合(collection)：第二层结构，在页面(page)的meta中定义（关键字: `collection`），用于进一步的分类，效果上和子目录一样。一个页面只能属于一个集合。
3. 标签(tag)：第三层结构，在页面(page)的meta中定义（关键字：`tag`）。一个页面可以有多个tags。

这样的结构能满足绝大多数个人维基用户的需求，并且管理维护也清晰简单。

> *注意*：集合是目录的子集，同一个目录下，配置了相同了集合名，才会认为是同一个集合，跨目录的集合没有任何关联性；且一个页面(page)只能属于一个集合。比如在工具目录下，有Git的文档，也有SVN的文档，增加一个集合「版本控制管理」给两者，可以使两者具有关联性。具体见下面的详细介绍。

> 对于`content`目录，新主题`simple2`放弃支持传统的多级目录结构。因为：
>
> - 个人维基很少需要这样的多级目录来存放文档文件
> - 降低生成器的复杂度
> - 降低主题开发的复杂度
>
> 但是我们以后可能会增加多级目录和集合并存的结构，不过目前来看，暂时还没有这个计划。如果想要支持对多级目录支持的主题，可以参考第一版的主题[simple](https://github.com/tankywoo/simiki/tree/master/simiki/themes/simple)。

------

下面是详细的介绍：

### 集合(collection)

比如content目录如下：

```
tree content
content
├── linux
│   └── other2.md
└── tool
    ├── git.md
    ├── other1.md
    └── svn.md
```

现在没有定义集合，生成的`pages`结构如下（无关字段已省略）：

```
[
  {
    "name": "linux",        # 目录名
    "pages": [
      ...
    ]
  },
  {
    "name": "tool",        # 目录名
    "pages": [             # 目录下的所有页面和集合
      {
        "date": "2016-01-01 00:00",
        "fname": "git.md",        # 无集合的页面
        ...
      },
      {
        "date": "2016-01-03 00:00",
        "fname": "other1.md",
        ...
      },
      {
        "date": "2016-01-02 00:00",
        "fname": "svn.md",
        ...
      }
    ]
  }
]
```

现在给git.md和svn.md增加相同的集合：

```
$ cat content/tool/{git,svn}.md
---
title: "Git"
date: 2016-01-01 00:00
collection: Version Control
---

---
title: "SVN"
date: 2016-01-02 00:00
collection: Version Control
---
```

这时`pages`的结构如下：

```
[
  {
    "name": "linux",        # 目录名
    "pages": [
      ...
    ]
  },
  {
    "name": "tool",        # 目录名
    "pages": [             # 目录下的所有页面和集合
      {
        "date": "2016-01-03 00:00",
        "fname": "other1.md",        # 无集合的页面
        ...
      },
      {
        "name": "Version Control",        # 集合名
        "pages": [                        # 集合下的所有页面
          {
            "collection": "Version Control",
            "fname": "git.md",
            "date": "2016-01-01 00:00"
            ...
          },
          {
            "collection": "Version Control",
            "fname": "svn.md",
            "date": "2016-01-02 00:00"
            ...
          }
        ]
      }
    ]
  }
]
```

可以看到，在同一个目录下，配置了相同的集合(collection)后：

- 同一个目录下，**未配置**集合(collection)的页面(page)和集合是同一级结构
- 同一个目录下，配置集合(collection)的页面(page)处于集合中更深一级的结构中

### 标签(tag)

标签使多篇Wiki之间互相有关联性。

如下例子，两篇Wiki，都是和Vim相关的：

```
==> content/book/practical-vim.md <==
---
title: "Practical Vim"
date: 2014-11-13 22:11
tag: vim  # 以逗号分隔的字符串方式配置tag
---

==> content/tool/vim.md <==
---
title: "Vim"
date: 2013-08-17 07:32
tag:  # 以列表的方式配置tag
  - vim
---
```

`page.relation`变量会维护与此页面相关的其它页面信息：

```
{
    'filename': u'vim.html',
    'relation': [
        {
            'category': u'book',
            'date': '2014-11-13 22:11',
            'filename': u'practical-vim.html',
            'tag': ['vim'],
            'title': 'Practical Vim'
        }
    ],
    'tag': ['vim'],
    'title': 'Vim',
    ...
}
```
