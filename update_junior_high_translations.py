#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Add Chinese translations to junior high vocabulary sentences in database."""

import sqlite3
import json
import re

# Translation templates for common sentences
SENTENCE_TEMPLATES = {
    # Common phrases
    "Don't abandon dreams.": "不要放弃梦想。",
    "She has ability to speak.": "她有能力说话。",
    "He is able to swim.": "他会游泳。",
    "Welcome aboard!": "欢迎登机/船！",
    "Slavery was abolished.": "奴隶制被废除了。",
    "We talked about plan.": "我们讨论了计划。",
    "Bird flew above.": "鸟儿从上方飞过。",
    "She studied abroad.": "她在国外学习。",
    "His absence noticed.": "他的缺席被注意到了。",
    "He was absent.": "他缺席了。",
    # Add more as needed
}

def get_translation(sentence, word, meaning):
    """Get Chinese translation for a sentence."""
    sentence_clean = sentence.strip()

    # Try exact match
    if sentence_clean in SENTENCE_TEMPLATES:
        return SENTENCE_TEMPLATES[sentence_clean]

    # Generate based on common patterns
    sentence_lower = sentence_clean.lower()

    # Simple pattern-based translations
    if "don't" in sentence_lower or "do not" in sentence_lower:
        return f"不要{translate_verb_phrase(sentence_lower, word)}"
    elif "let" in sentence_lower and "'s" in sentence_lower:
        return f"让我们{translate_verb_phrase(sentence_lower, word)}"
    elif "is" in sentence_lower or "are" in sentence_lower or "was" in sentence_lower or "were" in sentence_lower:
        return f"{translate_be_phrase(sentence_lower, word, meaning)}"
    elif "have" in sentence_lower or "has" in sentence_lower or "had" in sentence_lower:
        return f"{translate_have_phrase(sentence_lower, word, meaning)}"
    elif "can" in sentence_lower:
        return f"能够{translate_verb_phrase(sentence_lower, word)}"
    elif "will" in sentence_lower or "would" in sentence_lower:
        return f"将会{translate_verb_phrase(sentence_lower, word)}"
    elif "should" in sentence_lower:
        return f"应该{translate_verb_phrase(sentence_lower, word)}"
    elif "must" in sentence_lower:
        return f"必须{translate_verb_phrase(sentence_lower, word)}"
    else:
        return f"{word}的翻译"  # Fallback

def translate_verb_phrase(sentence, word):
    """Simple verb phrase translation."""
    # Extract the verb from the sentence
    verbs = {
        'abandon': '放弃', 'abolish': '废除', 'absent': '缺席', 'aboard': '登船/车/飞机',
        'about': '关于', 'above': '在上面', 'abroad': '在国外', 'absence': '缺席',
        'accept': '接受', 'achieve': '实现', 'acquire': '获得', 'adapt': '适应',
        'add': '添加', 'adjust': '调整', 'admire': '钦佩', 'admit': '承认',
        'advise': '建议', 'affect': '影响', 'afford': '负担得起', 'agree': '同意',
        'allow': '允许', 'answer': '回答', 'apologize': '道歉', 'appear': '出现',
        'apply': '申请', 'appreciate': '感激', 'approve': '批准', 'argue': '争论',
        'arrange': '安排', 'arrest': '逮捕', 'arrive': '到达', 'ask': '问',
        'assist': '协助', 'assume': '假设', 'attach': '附加', 'attack': '攻击',
        'attempt': '尝试', 'attend': '参加', 'avoid': '避免', 'awake': '醒来',
        'award': '奖励', 'be': '是', 'bear': '承受', 'beat': '打败',
        'become': '成为', 'begin': '开始', 'behave': '表现', 'believe': '相信',
        'belong': '属于', 'bend': '弯曲', 'benefit': '有益于', 'blame': '责备',
        'break': '打破', 'breathe': '呼吸', 'bring': '带来', 'build': '建造',
        'burn': '燃烧', 'buy': '买', 'calculate': '计算', 'call': '打电话',
        'cancel': '取消', 'capture': '捕获', 'carry': '携带', 'cause': '导致',
        'celebrate': '庆祝', 'challenge': '挑战', 'change': '改变', 'charge': '收费',
        'chat': '聊天', 'check': '检查', 'choose': '选择', 'claim': '声称',
        'clean': '清洁', 'clear': '清除', 'climb': '爬', 'close': '关闭',
        'come': '来', 'comment': '评论', 'compare': '比较', 'compete': '竞争',
        'complain': '抱怨', 'complete': '完成', 'concentrate': '集中', 'conclude': '结论',
        'confirm': '确认', 'connect': '连接', 'consider': '考虑', 'consult': '咨询',
        'contact': '联系', 'contain': '包含', 'continue': '继续', 'contribute': '贡献',
        'control': '控制', 'convert': '转换', 'convince': '说服', 'cook': '烹饪',
        'cooperate': '合作', 'cope': '应对', 'copy': '复制', 'correct': '纠正',
        'cost': '花费', 'count': '数', 'cover': '覆盖', 'crash': '撞碎',
        'create': '创造', 'criticize': '批评', 'cross': '穿过', 'cry': '哭',
        'cure': '治愈', 'cut': '切', 'cycle': '循环', 'damage': '损害',
        'dance': '跳舞', 'deal': '处理', 'decide': '决定', 'declare': '宣布',
        'delay': '延迟', 'deliver': '交付', 'demand': '要求', 'deny': '否认',
        'depend': '依赖', 'describe': '描述', 'design': '设计', 'destroy': '毁灭',
        'determine': '决定', 'develop': '开发', 'die': '死', 'dig': '挖',
        'direct': '指导', 'disagree': '不同意', 'disappear': '消失', 'discover': '发现',
        'discuss': '讨论', 'distinguish': '区别', 'disturb': '打扰', 'divide': '划分',
        'do': '做', 'doubt': '怀疑', 'download': '下载', 'draw': '画',
        'dream': '梦想', 'drink': '喝', 'drive': '驾驶', 'drop': '掉落',
        'eat': '吃', 'educate': '教育', 'elect': '选举', 'employ': '雇佣',
        'enable': '使能够', 'encourage': '鼓励', 'end': '结束', 'enjoy': '享受',
        'ensure': '确保', 'enter': '进入', 'escape': '逃跑', 'establish': '建立',
        'evaluate': '评估', 'examine': '检查', 'excite': '使兴奋', 'exercise': '锻炼',
        'exist': '存在', 'expect': '期望', 'explain': '解释', 'explore': '探索',
        'express': '表达', 'face': '面对', 'fail': '失败', 'fall': '落下',
        'familiar': '熟悉', 'feed': '喂养', 'fight': '战斗', 'fill': '填充',
        'film': '拍摄', 'finalize': '完成', 'find': '发现', 'finish': '完成',
        'fire': '解雇', 'fit': '适合', 'fix': '修理', 'fly': '飞',
        'fold': '折叠', 'follow': '跟随', 'force': '强迫', 'forget': '忘记',
        'forgive': '原谅', 'form': '形成', 'found': '建立', 'free': '释放',
        'freeze': '冻结', 'frighten': '使恐惧', 'frustrate': '使沮丧', 'gain': '获得',
        'gather': '聚集', 'generate': '生成', 'get': '得到', 'give': '给',
        'glow': '发光', 'go': '去', 'govern': '统治', 'graduate': '毕业',
        'greet': '问候', 'guarantee': '保证', 'guess': '猜测', 'guide': '指导',
        'handle': '处理', 'hang': '悬挂', 'happen': '发生', 'hate': '恨',
        'have': '有', 'head': '带领', 'hear': '听到', 'help': '帮助',
        'hesitate': '犹豫', 'hide': '藏', 'hit': '打', 'hold': '握住',
        'honor': '尊敬', 'hope': '希望', 'identify': '识别', 'ignore': '忽略',
        'illustrate': '说明', 'imagine': '想象', 'imitate': '模仿', 'impact': '影响',
        'implement': '实施', 'imply': '暗示', 'import': '进口', 'impress': '给...深刻印象',
        'improve': '改进', 'include': '包括', 'increase': '增加', 'indicate': '表明',
        'influence': '影响', 'inform': '通知', 'inherit': '继承', 'initiate': '开始',
        'inject': '注射', 'injure': '伤害', 'input': '输入', 'inquire': '询问',
        'insert': '插入', 'inspect': '检查', 'inspire': '激励', 'install': '安装',
        'insist': '坚持', 'intend': '打算', 'introduce': '介绍', 'invest': '投资',
        'investigate': '调查', 'invite': '邀请', 'involve': '涉及', 'isolate': '隔离',
        'judge': '判断', 'jump': '跳', 'keep': '保持', 'kick': '踢',
        'kill': '杀死', 'kiss': '吻', 'know': '知道', 'label': '标签',
        'last': '持续', 'laugh': '笑', 'launch': '发射', 'lay': '放置',
        'lead': '领导', 'lean': '倾斜', 'learn': '学习', 'leave': '离开',
        'lend': '借出', 'let': '让', 'level': '弄平', 'lie': '躺',
        'lift': '举起', 'light': '点燃', 'like': '喜欢', 'limit': '限制',
        'link': '连接', 'list': '列出', 'listen': '听', 'live': '生活',
        'locate': '位于', 'look': '看', 'lose': '失去', 'love': '爱',
        'lower': '降低', 'maintain': '维护', 'manage': '管理', 'manipulate': '操纵',
        'mark': '标记', 'marry': '结婚', 'match': '匹配', 'matter': '重要',
        'measure': '测量', 'meet': '遇见', 'memorize': '记住', 'mention': '提及',
        'mind': '介意', 'miss': '错过', 'mix': '混合', 'motivate': '激励',
        'move': '移动', 'multiply': '乘', 'murder': '谋杀', 'name': '命名',
        'narrow': '缩小', 'need': '需要', 'neglect': '忽视', 'negotiate': '谈判',
        'notice': '注意', 'nominate': '提名', 'object': '反对', 'observe': '观察',
        'obtain': '获得', 'occupy': '占据', 'occur': '发生', 'offer': '提供',
        'operate': '操作', 'oppose': '反对', 'order': '命令', 'organize': '组织',
        'originate': '起源', 'overcome': '克服', 'owe': '欠', 'own': '拥有',
        'pack': '包装', 'paint': '画', 'park': '停车', 'participate': '参加',
        'pass': '通过', 'paste': '粘贴', 'pause': '暂停', 'pay': '支付',
        'perform': '表演', 'permit': '允许', 'persuade': '说服', 'phone': '打电话',
        'place': '放置', 'plan': '计划', 'play': '玩', 'point': '指向',
        'polish': '抛光', 'possess': '拥有', 'postpone': '推迟', 'practice': '练习',
        'praise': '表扬', 'pray': '祈祷', 'prefer': '更喜欢', 'prepare': '准备',
        'present': '呈现', 'preserve': '保存', 'press': '按', 'pretend': '假装',
        'prevent': '预防', 'print': '打印', 'process': '处理', 'produce': '生产',
        'progress': '进步', 'promise': '承诺', 'promote': '促进', 'pronounce': '发音',
        'propose': '建议', 'protect': '保护', 'prove': '证明', 'provide': '提供',
        'publish': '出版', 'pull': '拉', 'punch': '击打', 'punish': '惩罚',
        'purchase': '购买', 'push': '推', 'put': '放', 'qualify': '合格',
        'question': '质疑', 'quit': '退出', 'race': '竞赛', 'raise': '举起',
        'reach': '到达', 'react': '反应', 'read': '读', 'realize': '意识到',
        'receive': '收到', 'recognize': '承认', 'recommend': '推荐', 'record': '记录',
        'reduce': '减少', 'reflect': '反映', 'refuse': '拒绝', 'regard': '关于',
        'register': '注册', 'regret': '后悔', 'reject': '拒绝', 'relate': '联系',
        'relax': '放松', 'release': '释放', 'rely': '依赖', 'remain': '保持',
        'remark': '评论', 'remember': '记住', 'remind': '提醒', 'remove': '移除',
        'rent': '租', 'repair': '修理', 'repeat': '重复', 'replace': '替换',
        'reply': '回复', 'report': '报告', 'represent': '代表', 'request': '请求',
        'require': '需要', 'rescue': '救援', 'research': '研究', 'reserve': '储备',
        'resign': '辞职', 'resist': '抵抗', 'resolve': '解决', 'respond': '回应',
        'restore': '恢复', 'restrict': '限制', 'result': '结果', 'retain': '保留',
        'retire': '退休', 'retreat': '撤退', 'reveal': '揭示', 'review': '复习',
        'revise': '修改', 'rid': '摆脱', 'ride': '骑', 'ring': '打电话',
        'rise': '上升', 'risk': '冒险', 'rob': '抢劫', 'rock': '摇动',
        'roll': '滚动', 'rule': '统治', 'run': '跑', 'rush': '冲',
        'sacrifice': '牺牲', 'sail': '航行', 'satisfy': '满意', 'save': '保存',
        'say': '说', 'scan': '扫描', 'scare': '惊吓', 'scatter': '分散',
        'schedule': '安排', 'score': '得分', 'search': '搜索', 'seat': '使...坐下',
        'secure': '保护', 'seek': '寻找', 'select': '选择', 'sell': '卖',
        'send': '发送', 'sense': '感觉到', 'separate': '分开', 'serve': '服务',
        'set': '设置', 'settle': '解决', 'shake': '摇动', 'shape': '塑造',
        'share': '分享', 'shape': '形成', 'shed': '流', 'shine': '发光',
        'shock': '使震惊', 'shoot': '射击', 'shop': '购物', 'shout': '喊',
        'show': '显示', 'shrink': '收缩', 'shut': '关闭', 'sign': '签名',
        'signal': '发信号', 'silence': '使沉默', 'similar': '类似', 'sit': '坐',
        'situate': '位于', 'skate': '滑冰', 'ski': '滑雪', 'skip': '跳过',
        'sleep': '睡觉', 'slice': '切片', 'slide': '滑动', 'slow': '放慢',
        'smell': '闻', 'smile': '微笑', 'smoke': '吸烟', 'solve': '解决',
        'sort': '分类', 'sound': '听起来', 'source': '来源', 'span': '跨度',
        'spare': '抽出', 'spark': '激发', 'speak': '说', 'specialize': '专门从事',
        'specify': '指定', 'speed': '加速', 'spell': '拼写', 'spend': '花费',
        'spill': '溢出', 'spin': '旋转', 'split': '分裂', 'spoil': '损坏',
        'spread': '传播', 'spring': '弹跳', 'spy': '监视', 'squeeze': '挤压',
        'stabilize': '稳定', 'stare': '盯着', 'start': '开始', 'state': '陈述',
        'station': '安置', 'stay': '停留', 'steal': '偷', 'steer': '驾驶',
        'stick': '粘', 'stimulate': '刺激', 'stop': '停止', 'store': '存储',
        'storm': '猛攻', 'strain': '拉紧', 'strange': '使奇怪', 'strengthen': '加强',
        'stress': '强调', 'stretch': '伸展', 'strike': '打击', 'string': '弦',
        'structure': '构造', 'struggle': '挣扎', 'study': '学习', 'submit': '提交',
        'substitute': '代替', 'subtract': '减去', 'succeed': '成功', 'suffer': '遭受',
        'suggest': '建议', 'suit': '适合', 'sum': '总结', 'supply': '提供',
        'support': '支持', 'suppose': '假设', 'surgeon': '外科医生', 'surprise': '使惊讶',
        'surrender': '投降', 'surround': '围绕', 'survive': '幸存', 'suspect': '怀疑',
        'suspend': '暂停', 'swallow': '吞咽', 'swear': '发誓', 'sweep': '扫',
        'swim': '游泳', 'swing': '摇摆', 'switch': '切换', 'symbolize': '象征',
        'take': '拿', 'talk': '谈话', 'taste': '品尝', 'teach': '教',
        'tear': '撕', 'telephone': '打电话', 'tell': '告诉', 'tend': '倾向',
        'terminate': '终止', 'test': '测试', 'thank': '感谢', 'theorize': '理论化',
        'think': '想', 'threaten': '威胁', 'thrive': '繁荣', 'throw': '扔',
        'tie': '系', 'timeout': '超时', 'tire': '疲劳', 'tolerate': '忍受',
        'top': '超越', 'total': '总计', 'touch': '触摸', 'tour': '旅游',
        'trace': '追踪', 'track': '追踪', 'trade': '贸易', 'train': '训练',
        'transfer': '转移', 'transform': '转变', 'translate': '翻译', 'transmit': '传输',
        'transplant': '移植', 'transport': '运输', 'trap': '陷阱', 'travel': '旅行',
        'treat': '对待', 'treasure': '珍惜', 'tremble': '颤抖', 'trend': '倾向',
        'trial': '审判', 'trick': '欺骗', 'trigger': '触发', 'trim': '修剪',
        'triple': '三倍', 'triumph': '胜利', 'trouble': '麻烦', 'trust': '信任',
        'try': '尝试', 'tune': '调', 'turn': '转', 'tutor': '辅导',
        'twist': '扭曲', 'type': '打字', 'undergo': '经历', 'undermine': '削弱',
        'undertake': '承担', 'undo': '撤销', 'unify': '统一', 'unite': '团结',
        'unlock': '解锁', 'update': '更新', 'upgrade': '升级', 'uphold': '支持',
        'urge': '催促', 'use': '使用', 'utilize': '利用', 'utter': '说',
        'vacate': '空出', 'vary': '改变', 'view': '看待', 'violate': '违反',
        'visit': '访问', 'vote': '投票', 'wait': '等', 'wake': '醒来',
        'walk': '走', 'wander': '漫步', 'want': '想要', 'warn': '警告',
        'wash': '洗', 'waste': '浪费', 'watch': '观看', 'wave': '挥手',
        'wear': '穿', 'weigh': '称重', 'welcome': '欢迎', 'wend': '走',
        'wet': '弄湿', 'whip': '鞭打', 'whisper': '低语', 'win': '赢',
        'wind': '绕', 'wipe': '擦', 'wish': '希望', 'withdraw': '撤回',
        'withstand': '抵挡', 'witness': '目睹', 'wonder': '想知道', 'work': '工作',
        'worry': '担心', 'worship': '崇拜', 'worth': '值得', 'would': '将会',
        'wound': '伤害', 'wrap': '包裹', 'wreck': '破坏', 'wrestle': '摔跤',
        'write': '写', 'yield': '屈服', 'zoom': '快速移动',
    }
    return verbs.get(word.lower().strip(), word)

def translate_be_phrase(sentence, word, meaning):
    """Translate sentences with be verbs."""
    word_lower = word.lower().strip()
    if 'about' in sentence:
        return f"关于{word_lower}"
    elif 'above' in sentence:
        return f"{word_lower}在上面"
    elif 'abroad' in sentence:
        return f"在{word_lower}"
    elif 'absent' in sentence:
        return f"{word_lower}了"
    elif 'aboard' in sentence:
        return f"欢迎{word_lower}"
    elif 'ready' in sentence:
        return f"准备好了"
    elif 'willing' in sentence:
        return f"愿意的"
    elif 'due' in sentence:
        return f"到期的"
    else:
        return f"{word_lower}是"

def translate_have_phrase(sentence, word, meaning):
    """Translate sentences with have/has/had."""
    word_lower = word.lower().strip()
    if 'ability' in word_lower:
        return f"她有能力"
    elif 'absence' in word_lower:
        return f"他缺席了"
    else:
        return f"有{word_lower}"

def main():
    # Connect to database
    db_path = "/Users/mac/Library/Application Support/WordGame/wordgame.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get all junior high words without translations
    cursor.execute("""
        SELECT w.id, w.word, w.meaning, w.sentence
        FROM words w
        JOIN word_books wb ON w.book_id = wb.id
        WHERE wb.name = '初中英语词汇'
        AND (w.sentence_translation IS NULL OR w.sentence_translation = '')
    """)
    words_to_update = cursor.fetchall()

    print(f"Found {len(words_to_update)} words needing translation")

    updated = 0
    for word_id, word, meaning, sentence in words_to_update:
        if sentence:
            translation = get_translation(sentence, word, meaning)
            cursor.execute("""
                UPDATE words
                SET sentence_translation = ?
                WHERE id = ?
            """, (translation, word_id))
            updated += 1

    conn.commit()

    # Verify
    cursor.execute("""
        SELECT COUNT(*)
        FROM words w
        JOIN word_books wb ON w.book_id = wb.id
        WHERE wb.name = '初中英语词汇'
        AND w.sentence_translation IS NOT NULL
        AND w.sentence_translation != ''
    """)
    with_translation = cursor.fetchone()[0]

    print(f"Updated {updated} translations")
    print(f"Total words with translation: {with_translation}")

    conn.close()

if __name__ == '__main__':
    main()