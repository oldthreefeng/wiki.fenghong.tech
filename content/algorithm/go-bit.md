---
title: "Go位运算续"
date: 2019-10-10 14:40
tag: 
  - bit
  - leetcode
---

[TOC]

> ### 背景
>
> 位运算上篇文章[位运算](https://wiki.fenghong.tech/algorithm/go-bit-byte.html)简单介绍了什么是位运算,以及`goalng`位运算的特点.这篇结合几个实例深入位运算的理解

## 异或

异或的真值表如下:

| a    | b    | ⊕    |
| ---- | ---- | ---- |
| 1    | 0    | 1    |
| 1    | 1    | 0    |
| 0    | 0    | 0    |
| 0    | 1    | 1    |

### 一些规律

交换律：`a ^ b ^ c <=> a ^ c ^ b`

任何数于0异或为该数: `0 ^ n => n`

相同的数异或为0: `n ^ n => 0`

任何数`&`该数的取反为0: `x & ^x = 0`,

任何数`&`非0为该数: `x & ^0 = x`;

逻辑操作与加减法结合起来的恒等式: 

`-x = ^x + 1 `

`-x = ^(x-1)`

`^x = -x -1`

`-^x = x +1`

...

## 示例

### 136. singleNumber1

#### 描述

给定一个**非空**整数数组，除了**某个元素只出现一次**以外，**其余每个元素均出现两次**。找出那个只出现了一次的元素。

**说明:** 

你的算法应该具有线性时间复杂度O(n),空间复杂度为O(1)

**示例 1:**

```
输入: [2,2,1]
输出: 1
```

**示例 2:**

```
输入: [4,1,2,1,2]
输出: 4
```

#### 思路

```
根据这个规律: 
相同的数异或为0: n ^ n => 0
交换律：a ^ b ^ c <=> a ^ c ^ b

var a = [2,3,2,4,4]
2 ^ 3 ^ 2 ^ 4 ^ 4等价于 2 ^ 2 ^ 4 ^ 4 ^ 3 => 0 ^ 0 ^3 => 3
```

#### 代码

```go
func SingleNumber(nums []int) int {
	x := nums[0]
	for i := 0; i < len(nums); i++ {
		x ^= nums[i]
	}
	return x
}
```

### 137. SingleNumber2

#### 描述

给定一个**非空**整数数组，除了**某个元素只出现一次**以外，**其余每个元素均出现了三次**。找出那个只出现了一次的元素。

**说明:** 

你的算法应该具有线性时间复杂度O(n),空间复杂度为O(1)

**示例 1:**

```
输入: [2,2,3,2]
输出: 3
```

**示例 2:**

```
输入: [0,1,0,1,0,1,99]
输出: 99
```

#### 思路1

```
大佬说: 能设计一个状态转换电路，使得一个数出现3次时能自动抵消为0，最后剩下的就是只出现1次的数。
则有:
x出现一次:
	a = (a ^ x) & ^b ==>  a = x
	b = (b ^ x) & ^a ==> (因为a=x,所有b=0)
x出现两次:
	a = (a ^ x) & ^b ==>  a = (x ^ x) & ^0 ==> a = 0
	b = (b ^ x) & ^a ==>  b = (0 ^ x) & ^0 ==> b = x
x出现三次:
	a = (a ^ x) & ^b ==>  a = (0 ^ x) & ^x ==> a = 0
	b = (b ^ x) & ^a ==>  b = (x ^ x) & ^0 ==> b = 0
```

#### 代码

```go
func SingleNumber2(nums []int) int {
	a, b := 0, 0
	for _, x := range nums {
		a = (a ^ x) & ^b
		b = (b ^ x) & ^a
	}
	return a
}
```

#### 思路2

```
利用hashmap来存储出现的次数. key存储该数, value存储该数出现的状态.
```

#### 代码

```
func SingleNumber2x(nums []int) int {
	var (
		map1 = make(map[int]int8)
	)
	for _, value := range nums {
		map1[value]++
	}
	for key, v := range map1 {
		if v == 1 {
			return key
		}
	}
	return 0
}
```

#### 测试性能

两种思路性能比对,Benchmark测试

```
func BenchmarkSingleNumber2(b *testing.B) {
	var a = []int{1, 1, 1, 3, 3, 3, 5, 5, 5, 2, 6, 6, 6, 8, 8, 8}
	b.ResetTimer()
	for i := 0; i <= b.N; i++ {
		SingleNumber2(a)
	}
}

func BenchmarkSingleNumber2x(b *testing.B) {
	var a = []int{1, 1, 1, 3, 3, 3, 5, 5, 5, 2, 6, 6, 6, 8, 8, 8}
	b.ResetTimer()
	for i := 0; i <= b.N; i++ {
		SingleNumber2x(a)
	}
}
```
测试性能

```
$ go test -bench=. -benchmem -run=none

goos: windows
goarch: amd64
pkg: gogs.wangke.co/go/algo/leetcode
BenchmarkSingleNumber2-4        63165872                24.6 ns/op             0 B/op          0 allocs/op
BenchmarkSingleNumber2x-4        2542356               472 ns/op              64 B/op          2 allocs/op
PASS
ok      gogs.wangke.co/go/algo/leetcode 3.508s
```

很明显,利用`hashmap`会产生多余的内存空间.速度下降.[性能比对疑惑](https://leetcode-cn.com/problems/single-number-ii/solution/mapji-lu-chu-xian-ci-shu-wei-yun-suan-yi-huo-fang-/),`leetcode`上面是`hashmap`占优.

### 260. SingleNumber3

#### 描述

给定一个整数数组 `nums`，其中**恰好有两个元素只出现一次**，**其余所有元素均出现两次**。 找出只出现一次的那两个元素。

**示例 :**

```
输入: [1,2,1,3,2,5]
输出: [3,5]
```
**注意：**

结果输出的顺序并不重要，对于上面的例子， **[5, 3] 也是正确答案**。
你的算法应该具有线性时间复杂度。你能否仅使用常数空间复杂度来实现？

#### 思路

位运算，异或运算。对于一个数组`nums = [1, 1 , 2, 2, 3, 4, 4, 5]`。
其一，如果，进行一次全部异或运算，将会得到`3 ^ 5`。
其二， `3 ^ 5 = 110b`。那么在出现`1`的位置，必然一个为`1`一个为`0`，这样就可以根据特征区分出两个数字。

[Hacker's Delight 2nd Edition Chinese](https://raw.githubusercontent.com/jyfc/ebook/master/02_algorithm/算法心得：高效算法的奥秘（中文第2版）.pdf)


>Use the following formula to isolate the rightmost 1-bit, producing 0 if none (eg, 01011000 ==> 0000 1000): 
>				`x & (-x)`
>
>翻译过来: 下列公式可以保留x中最靠右且值为1的位元,并将其余位元置0;若不存在,则生成的数为0.(01011000 ==> 0000 1000):
>
>​			`x & (-x)`


其三，于是将问题转化为了“一个数字出现1次，其他数字出现两次”。

#### 代码

```
func SingleNumber3(nums []int) []int {
	var diff int
	var res = make([]int, 2)
	for _, v := range nums {
		diff ^= v
	}
	//  3(011),5(101) 两个不一样，  diff = 110
	// diff &= ^diff +1 //==> 找到只出现一次的两个数最右侧不相同的位
	diff &= -diff
	// diff = 10
	for _, v := range nums {
		if v&diff == 0 {
			res[0] ^= v
		} else {
			res[1] ^= v
		}
	}
	return res
}
```

#### 测试用例

```go
func TestSingleNumber3(t *testing.T) {
	type args struct {
		nums []int
	}
	tests := []struct {
		name string
		args args
		want []int
	}{
		{"test01",args{[]int{1,2,1,3,2,5}},[]int{3,5}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SingleNumber3(tt.args.nums)
			sort.Ints(got) //返回的数组未排序,比较起来不方便
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("SingleNumber3() = %v, want %v", got, tt.want)
			}
		})
	}
}
/*
=== RUN   TestSingleNumber3
=== RUN   TestSingleNumber3/test01
--- PASS: TestSingleNumber3 (0.00s)
    --- PASS: TestSingleNumber3/test01 (0.00s)
PASS
*/
```

感谢阅读~[源码](https://gogs.wangke.co/go/algo/src/master/leetcode/136-singlenumber.go)

### 参考

- [leetcode](https://leetcode-cn.com/problems/single-number-iii/)

