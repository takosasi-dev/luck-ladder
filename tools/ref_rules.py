# LuckLadder 仕様書 v3 の §9.2〜§9.5 の固定値を出した計算の写し(作成 2026-11-11)。
# リポジトリでは tools/ref_rules.py に置く。python3 で動かすと固定値を表示する。
# 調整値(BASE など)を変えたら、ここも同じ値にして固定値を取り直す。
import statistics, datetime
M=0xFFFFFFFF
def fnv(s):
    h=2166136261
    for b in s.encode(): h=((h^b)*16777619)&M
    return h
class X:
    def __init__(s,seed): s.x=seed&M or 1
    def next(s):
        x=s.x; x^=(x<<13)&M; x^=x>>17; x^=(x<<5)&M; s.x=x; return x
    def ni(s,n): return s.next()%n
def deck(seed):
    r=X(seed); d=list(range(52))
    for i in range(51,0,-1):
        j=r.ni(i+1); d[i],d[j]=d[j],d[i]
    return d
rank=lambda c:c%13+1
BASE=100;GCAP=5000;SCAP=10;LIVES=4;LIFE_EVERY=3;CLEAR=3000;LIFEB=1000
def counts(rem,cur):
    return (sum(1 for c in rem if rank(c)>cur), sum(1 for c in rem if rank(c)<cur), sum(1 for c in rem if rank(c)==cur))
def gain(n,w,streak):
    g=min(BASE*n*n//(w*w),GCAP)
    return g*(10+min(streak,SCAP))//10
def play(seed,policy,L=None,K=None):
    L=L or LIVES; K=K or LIFE_EVERY
    d=deck(seed); cur=rank(d[0]); i=1; score=pot=streak=0; lives=L; log=[];best=0;hits=miss=banks=same_hits=0;acts=''
    while lives>0 and i<52:
        rem=d[i:]; n=len(rem); hi,lo,sa=counts(rem,cur)
        act=policy(cur,n,hi,lo,sa,pot,streak,lives)
        if act=='B': score+=pot; pot=0; streak=0; banks+=1; log.append('B'); acts+='B'; continue
        w={'H':hi,'L':lo,'S':sa}[act]; assert w>0
        nx=rank(d[i]); i+=1; acts+=act
        ok=(act=='H' and nx>cur) or (act=='L' and nx<cur) or (act=='S' and nx==cur)
        if ok:
            pot+=gain(n,w,streak); streak+=1; hits+=1; best=max(best,streak); same_hits+=(act=='S')
            if streak%K==0 and lives<L: lives+=1
            r='W'
        else: pot=0; streak=0; lives-=1; miss+=1; r='X'
        log.append(act+r); cur=nx
    cl=lives>0
    if cl: score+=pot+CLEAR+LIFEB*lives
    return dict(score=score,clear=cl,lives=lives,draws=i-1,hits=hits,miss=miss,same_hits=same_hits,banks=banks,best=best,acts=acts,log=' '.join(log))
def best_hl(hi,lo,sa):
    if hi>=lo and hi>0: return 'H'
    if lo>0: return 'L'
    return 'S'
def P1(cur,n,hi,lo,sa,pot,st,lv):
    if pot>=800: return 'B'
    return best_hl(hi,lo,sa)
def P2(cur,n,hi,lo,sa,pot,st,lv):
    if pot>=800: return 'B'
    if pot==0 and lv>=2 and sa>=2: return 'S'
    return best_hl(hi,lo,sa)
if __name__=='__main__':
    import sys
    if len(sys.argv)>1:
        for L,K in [(3,3),(3,2),(4,3),(4,2),(5,3)]:
            for nm,P in [('P1',P1),('P2',P2)]:
                rs=[play(fnv('bal%d'%k),P,L,K) for k in range(4000)]; sc=sorted(r['score'] for r in rs)
                print(L,K,nm,'mean',round(statistics.mean(sc)),'med',sc[2000],'p90',sc[3600],'max',sc[-1],'clear%',sum(r['clear'] for r in rs)/40,'draws',round(statistics.mean(r['draws'] for r in rs),1))
        sys.exit()
    print('fnv',fnv('a'),fnv('abc'),fnv('LL1:daily:2026-11-11'),fnv('LL1:test:1'))
    x=X(1);print([x.next() for _ in range(5)])
    for s in ['LL1:daily:2026-11-11','LL1:daily:2026-01-01','LL1:test:1','LL1:test:2']:
        d=deck(fnv(s)); print(s,d[:10],[rank(c) for c in d[:10]],sum(i*c for i,c in enumerate(d)))
    for a in [(51,24,0),(51,27,0),(40,10,0),(40,30,5),(20,1,0),(20,19,12),(3,2,10),(51,51,0),(30,4,3),(51,3,0),(6,3,2),(2,2,4)]: print(a,gain(*a))
    for nm,P in [('P1',P1),('P2',P2)]:
        found=0
        for k in range(1,400):
            r=play(fnv('LL1:test:%d'%k),P)
            if k<=3 or (r['clear'] and not found) or (nm=='P2' and r['same_hits'] and found<2 and k>3):
                print(nm,k,{a:b for a,b in r.items() if a!='log'});
                if r['clear'] or r['same_hits']: found+=1
            if found>=2 and k>3: break
    rs=[play(fnv('bal%d'%k),P1) for k in range(5000)]; sc=sorted(r['score'] for r in rs)
    print('P1 5000: mean',statistics.mean(sc),'med',sc[2500],'p90',sc[4500],'max',sc[-1],'clear%',sum(r['clear'] for r in rs)/50,'draws',statistics.mean(r['draws'] for r in rs))
    for dt in [(2026,1,1),(2026,11,11),(2027,1,1),(2028,2,29),(2025,12,31)]:
        print(dt,(datetime.date(*dt)-datetime.date(2026,1,1)).days+1)
