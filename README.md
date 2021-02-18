## 介绍
SUPERNOVA.CASH(超新星现金)是由 HIGGS NETWORK 所搭建的实验性算法稳定币
多重宇宙的重要组成部分。在超新星宇宙中，所有的参与者将会体验宇宙的起源、膨胀和稳
定以及众多算法稳定币星球的诞生、进化和湮灭。
过往的稳定币协议往往只包含纯抵押模式或者完全无抵押模式(算法稳定)中的一种。纯
抵押稳定币要么需要过度抵押链上资产，要么具有托管风险，并且应用规模受限于抵押资产
的多少；但这些设计确能提供相当稳定的固定汇率并具有一定的可信度。完全无抵押(算法)
稳定币补足了纯抵押稳定币的短板，无需信任，具有可扩展性等等；然而汇率的过度波动限
制了其应用场景。
超新星宇宙将同时包含这两种稳定币设计模式，并在不同的阶段进行开放。

## 第一阶段：起源
### （超新星现金 sCASH 的诞生：sCASH=2100）
SUPERNOVA.CASH 由 sCASH/Share 双代币模型和价格稳定基金 sFUND 组成，其中
#### sCASH：1 比 1 锚定 USDT(HECO)的算法稳定币
#### Share：算法稳定币宇宙的通用股份，Share 可以在不同的算法稳定币星球获得收益，如持 有 Share/sCASH 的 LP 可以在 sCASH rebase 时获取 sCASH 的分红
#### sCASH 挖矿
sCASH 的初始数量为 2100 枚，通过 8 个无损矿池和 1 个 sFUND 募集池进行分发
无损矿池
HUSD-300 每天 60 个 sCASH
USDT-300 每天 60 个 sCASH
HBTC-300 每天 60 个 sCASH
HETH-300 每天 60 个 sCASH
HT-300 每天 60 个 sCASH
HNEO-300 每天 60 个 sCASH
HFIL-100 每天 20 个 sCASH
HDOT-100 每天 20 个 sCASH
#### sFUND 募集
用户可以使用 USDT 每天换购 20 枚 sCASH，共五天，募集到的 USDT 均进入 sFUND 账户
用于 sCASH 价格的稳定。
#### sCASH 挖矿
sCASH 星球释放的 Share 总量为 10000 枚
当用户为 sCASH/USDT 以及 Share/USDT 提供流动性时可以获取 Share 奖励，奖励规则：
其中 7500 枚用于奖励 sCASH/USDT 的 LP 每天 62.5 枚，每 30 天减少 1/4
余下 2500 枚用于奖励 Share/USDT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
#### Rebase
每 24 小时为一个纪元 ERA，当 sCASH 在该纪元内的 TWAP 均价大于 1.05 时，sCASH 会
增发 total supply*(MIN{TWAP-1),1}枚 sCASH，用户质押 sCASH/sHARE 的 LP 可以平分
rebase 时增发的 sCASH 奖励的 95%，余下 5%进入 sFUND(通过 sCASH/USDT 兑换为
USDT，包括回购的 sCASH 也一同兑换) 当 sCASH 的 TWAP 均价小于 0.95 时，系统会优先使用 sFUND 中(1-TWAP)比例的 USDT
从 sCASH/USDT 回购 sCASH，并开放 sCASH 兑换 sHARE，释放数量为初始流动性释放
Share 数量的 1%(100 枚)，规则同平准基金公开募集，所募集到的 sCASH 均放置到 sFUND
中，直至 sCASH 价格回归 0.95 以上

## 第二阶段：膨胀
### （超新星现金 sCASH 的扩展：sCASH 流通量=[2100,210000000]）
超新星宇宙的膨胀过程中，将会诞生诸多算法稳定币星球并见证其相互耦合，其中包括
#### sHT：锚定 Huobi Token 价值的算法稳定币
诞生条件：sCASH 流通量>21,000
初始总量：2100 枚
获取方式：无损挖矿(2000 枚/4 天，sCASH/HNEO/HT/HETH/HBTC，100 枚/池/天)和平
准基金公开募集(100 枚，仅支持 wHT 出价)
获取 Share 数量：10000
2500 枚用于奖励 sHT/HT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4 2500 枚用于奖励 sHT/USDT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 sHT/sCASH 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 Share/USDT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
#### Rebase
每 24 小时为一个纪元 ERA， 当 sHT 在该纪元内的 TWAP 均价大于 1.05 时，sHT 会增发 total supply*(MIN{TWAP-1),1} 枚 sHT，用户质押 sHT/sHARE 的 LP 可以平分 rebase 时增发的 sHT 奖励的 95%，余下 5%
进入 sFUND(通过 sHT/HT 兑换为 HT，包括回购的 sHT 也一同兑换) 当 sHT 的 TWAP 均价小于 0.95 时，系统会优先使用 sFUND 中(1-TWAP)比例的 HT 从
sHT/HT 回购 sHT，并开放 sHT 兑换 sHARE，释放数量为初始流动性释放 Share 数量的
1%(100 枚)，规则同平准基金公开募集，所募集到的 sHT 均放置到 sFUND 中，直至 sHT 价
格回归 0.95 以上
#### sNEO：锚定 NEO 价值的算法稳定币
诞生条件：sCASH 流通量>210,000
初始总量：2100 枚
获取方式：无损挖矿(2000 枚/4 天，sCASH/sHT/HNEO/HETH/HBTC，100 枚/池/天)和平
准基金公开募集(100 枚，仅支持 HNEO 出价)
获取 Share 数量:10000
2500 枚用于奖励 sNEO/HNEO 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4 2500 枚用于奖励 sNEO/USDT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 sNEO/sCASH 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 Share/HNEO 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
#### Rebase
每 24 小时为一个纪元 ERA， 当 sNEO 在该纪元内的 TWAP 均价大于 1.05 时，sNEO 会增发 total supply*(MIN{TWAP-
1),1}枚sNEO，用户质押sNEO/sHARE的LP可以平分rebase时增发的sNEO奖励的95%，
余下 5%进入 sFUND(通过 sNEO/HNEO 兑换为 HNEO，包括回购的 sNEO 也一同兑换) 当 sNEO 的 TWAP 均价小于 0.95 时，系统会优先使用 sFUND 中(1-TWAP)比例的 HNEO
从 sNEO/HNEO 回购 sNEO，并开放 sNEO 兑换 Share，释放数量为初始流动性释放 Share
数量的 1%(100 枚)，规则同平准基金公开募集，所募集到的 sNEO 均放置到 sFUND 中，直
至 sNEO 价格回归 0.95 以上
#### sETH：锚定 ETH 价值的算法稳定币
诞生条件：sCASH 流通量>2,100,000
初始总量：210 枚
获取方式：无损挖矿(200 枚/4 天, sCASH/sHT/sNEO/HETH/HBTC，10 枚/池/天)和平准基
金公开募集(10 枚，仅支持 wETH 出价)
获取 Share 数量:10000
2500 枚用于奖励 sETH/HETH 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4 2500 枚用于奖励 sETH/USDT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 sETH/sCASH 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 Share/HETH 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
#### Rebase
每 24 小时为一个纪元 ERA， 当 sETH 在该纪元内的 TWAP 均价大于 1.05 时，sETH 会增发 total supply*(MIN{TWAP-
1),1}枚 sETH，用户质押 sETH/Share 的 LP 可以平分 rebase 时增发的 sETH 奖励的 95%，
余下 5%进入 sFUND(通过 sETH/HETH 兑换为 HETH，包括回购的 sETH 也一同兑换) 当 sETH 的 TWAP 均价小于 0.95 时，系统会优先使用 sFUND 中(1-TWAP)比例的 HETH 从
sETH/HETH 回购 sETH，并开放 sETH 兑换 Share，释放数量为初始流动性释放 Share 数量
的 1%(100 枚)，规则同平准基金公开募集，所募集到的 sETH 均放置到 sFUND 中，直至
sETH 价格回归 0.95 以上
#### sBTC：锚定 BTC 价值的算法稳定币
诞生条件：sCASH 流通量>21,000,000
初始总量：21 枚
获取方式：无损挖矿(20 枚/4 天, sCASH/sHT/sNEO/sETH/HBTC，1 枚/池/天)和平准基金
公开募集(1 枚，仅支持 HBTC 出价)
获取 Share 数量：10000
2500 枚用于奖励 sBTC/HBTC 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4 2500 枚用于奖励 sBTC/USDT 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 sBTC/sCASH 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
2500 枚用于奖励 Share/HBTC 的 LP，每天分发 20.83333 枚，每 30 天减少 1/4
#### Rebase
每 24 小时为一个纪元 ERA， 当 sBTC 在该纪元内的 TWAP 均价大于 1.05 时，sBTC 会增发 total supply*(MIN{TWAP-
1),1}枚 sBTC，用户质押 sBTC/sHARE 的 LP 可以平分 rebase 时增发的 sBTC 奖励的 95%，
余下 5%进入 sFUND(通过 sBTC/HBTC 兑换为 HBTC，包括回购的 sBTC 也一同兑换) 当 sBTC 的 TWAP 均价小于 0.95 时，系统会优先使用 sFUND 中(1-TWAP)比例的 HBTC 从
sBTC/HBTC 回购 sBTC，并开放 sBTC 兑换 Share，释放数量为初始流动性释放 Share 数量
的 1%(100 枚)，规则同平准基金公开募集，所募集到的 sBTC 均放置到 sFUND 中，直至
sBTC 价格回归 0.95 以上
此外，我们还欢迎全球各大区块链社区通过提供流动性的方式孕育更多的算法稳定币星球，
如 sDOT，sFIL，sBCH 等等
### 耦合
SUPERNOVA.CASH(超新星现金)与 HECO 生态的 Filda、LendHub、Channels 等去中心
化借贷平台合作开启算法稳定币借贷专区，共同开拓算法稳定币的实际应用场景，如抵押借 贷、信用借#贷等。 

## 第三阶段：稳定
### （超新星现金 sCASH 的稳定：sCASH=[210000000, +∞] ） 当 sCASH 的流通量大于 2.1 亿枚时，SUPERNOVA.CASH(超新星宇宙)正式进入第三阶段，
此时用户可以使用抵押品和 Share 一同铸造超新星宇宙中的诸多算法稳定币，以维持超新星
宇宙的稳定和平衡。 以 sCASH 为例阐述其具体过程。sCASH 始终能以$ 1 的价格从系统中铸造和赎回。这允许
套利者在公开市场上通过套利行为使 sCASH 的供需平衡。如果 sCASH 的市场价格高于目
标价格$ 1 时，那么就有套利者就会将$ 1 的价值放入系统来铸造 sCASH 代币并在公开市场
上以超过$ 1 的价格出售 sCASH。为了铸造新的 sCASH，用户必须向系统中投入$1 的价值。
唯一的区别在于抵押品和 Share 构成那$1 价值的比例是多少。当 sCASH 处于 100％抵押阶
段时，系统将 100％的抵押物价值抵押给 sCASH。随着协议进入分数阶段，在铸币时进入系
统的部分价值将来自于 Share。例如，以 98％的抵押率计算，每铸造$ 1 的 sCASH 都需要
$0.98 的抵押品和$0.02USD 的 Share。在 97％的抵押品比率中，每铸造一个 sCASH 都需
要$ 0.97 的抵押品和$ 0.03 的 Share 燃烧，依此类推。如果 sCASH 的市场价格低于$ 1 的
价格时，则套利者会在公开市场上廉价购买 sCASH 并从系统中以$ 1 的价值赎回抵押物和
Share。用户无论何时都可以从系统中兑换价值$1 的 sCASH。唯一的区别在于赎回者得到
的抵押品和 Share 的比例是多少。当 sCASH 处于 100％抵押阶段时，赎回时返回给用户的
价值全都由抵押品构成。当进入分数阶段时，在赎回过程中离开系统的部分价值将变为 Share
（铸造出来的 Share 以提供给赎回的用户）。例如，以 98％的抵押品比率，每个 sCASH 都
可以赎回$0.98 的抵押品和$0.02 的新铸造的 Share。以 97％的抵押品比率，每个 sCASH
都可以赎回$0.97 的抵押品和$0.02 的新铸造的 Share。
DAO
Share 的持有者除了可以通过质押 LP 获得 rebase 收益，使用 Share 与抵押资产合成算法
稳定币以外，还可以使用 Share 投票，共同行使治理权益。我们真诚邀请每一位 DeFi 生态
系统中的参与者，使用者，共同参与超新星宇宙创新发展与建设治理。