---
title: "Go 多项式实现(1)"
date: 2019-09-04 15:56
tag: 
  - go
  - markdown
  - polyn
collection: polyn
---

[TOC]

> 多项式链表的结构和接口均参考严蔚敏老师的（c语言版）《数据结构》。

网上的基本都是C/C++语言实现.这里用`golang`实现,算法和数据结构,其实用什么编程语言实现都一样,因为思想是一样的, go的话,不用处理`free`还有`malloc`等操作细节.

数据结构

```
type PolyNode struct {
	coef int   //系数
	exp  int   // 指数
	next *PolyNode  //指针
}
```

### 加法实现思想

```
p,q 为多项式A和B当前进行比较的某计算节点;  rear为指向"和多项式"链表的尾节点
p.exp < q.exp ; p后移
p.exp = q.exp ; 和为0,A中删除p,释放p,q;和不为零,修改p的数据域,释放q节点
p.exp > q.exp ; q节点插入p之前,q节点的指针在原来的链表上后移
```

### 减法实现

```
先把减数多项式的系数一一取相反数，然后调用加法函数即可实现。
```

### 乘法实现

$$M(x) = A(x) * B(x)$$

若:

$$A(x) = a_{0}+a_{1}x^1+a_2x^2+\cdots+a_{n-1}x^{n-1}+a_nx^n$$

则 :

$$M(x) = B(x) * [a_{0}+a_{1}x^1+a_2x^2+\cdots+a_{n-1}x^{n-1}+a_nx^n] $$,

因此:

$$M(x)=\sum_{e=1}^{n}a_iB(x)x^i$$

### 链表操作注意事项

注意事项:


- 需要对链表进行有效性判断
- 对于链表的操作过程中，首先要创建一个节点，并将头结点复制给新节点
- 如果要构建新的链表是，表头需要单独保存；同时每个节点需要创建新节点，完成赋值、指针操作；组后需要一个游标节点，负责将各个节点串联起来。
- 对于尾节点，最后一定要将其next指向NULL。
- 若在对链表操作时不想改变链表的值，则需要重新定义一个链表，并把原链表的内容赋给新链表。此时切记，不要把原链表的指针赋给新生成的结点，否则，在使用的过程中依旧会改变原链表，这是因为指针的特性

<script type="text/javascript" async
  src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=default">
</script>



