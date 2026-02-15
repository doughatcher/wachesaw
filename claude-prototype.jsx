import { useState, useCallback } from "react";

const BOARD_SIZE = 5;

const PIECES = {
  CHIEF:        { name: "Chief",        symW: "♔", symB: "♚", moves: "any",      desc: "King — 1 sq any. Lose = lose." },
  KEEPER:       { name: "Keeper",       symW: "♕", symB: "♛", moves: "any",      desc: "Queen — 1 sq any. Bodyguard." },
  HUNTER:       { name: "Hunter",       symW: "♖", symB: "♜", moves: "straight", desc: "Rook — 1 sq orthogonal." },
  RIVER_RUNNER: { name: "River Runner", symW: "♗", symB: "♝", moves: "diagonal", desc: "Bishop — 1 sq diagonal." },
  TRADER:       { name: "Trader",       symW: "♘", symB: "♞", moves: "knight",   desc: "Knight — L-jump. No cross-win." },
};

const STRAIGHT = [[-1,0],[1,0],[0,-1],[0,1]];
const DIAG = [[-1,-1],[-1,1],[1,-1],[1,1]];
const KNIGHT = [[-2,-1],[-2,1],[2,-1],[2,1],[-1,-2],[-1,2],[1,-2],[1,2]];
const ALL_ADJ = [...STRAIGHT, ...DIAG];

const createBoard = () => {
  const b = Array(BOARD_SIZE).fill(null).map(() => Array(BOARD_SIZE).fill(null));
  ["HUNTER","RIVER_RUNNER","CHIEF","KEEPER","TRADER"].forEach((t,c) => { b[4][c] = {type:t,player:"white"}; });
  ["TRADER","KEEPER","CHIEF","RIVER_RUNNER","HUNTER"].forEach((t,c) => { b[0][c] = {type:t,player:"black"}; });
  return b;
};

const cloneBoard = b => b.map(r => r.map(c => c ? {...c} : null));

const getDirs = t => {
  const m = PIECES[t].moves;
  return m==="any" ? ALL_ADJ : m==="straight" ? STRAIGHT : m==="diagonal" ? DIAG : m==="knight" ? KNIGHT : [];
};

const getMoves = (board, row, col) => {
  const p = board[row][col];
  if (!p) return [];
  const moves = [];
  for (const [dr,dc] of getDirs(p.type)) {
    const nr=row+dr, nc=col+dc;
    if (nr>=0 && nr<BOARD_SIZE && nc>=0 && nc<BOARD_SIZE) {
      const t = board[nr][nc];
      if (!t || t.player !== p.player) moves.push({row:nr,col:nc,type:"move"});
    }
  }
  for (const [dr,dc] of ALL_ADJ) {
    const nr=row+dr, nc=col+dc;
    if (nr>=0 && nr<BOARD_SIZE && nc>=0 && nc<BOARD_SIZE) {
      const t = board[nr][nc];
      if (t && t.player === p.player) moves.push({row:nr,col:nc,type:"swap"});
    }
  }
  return moves;
};

const getAllMoves = (board, player) => {
  const all = [];
  for (let r=0;r<BOARD_SIZE;r++) for (let c=0;c<BOARD_SIZE;c++)
    if (board[r][c]?.player===player)
      for (const m of getMoves(board,r,c))
        all.push({fr:r,fc:c,tr:m.row,tc:m.col,mt:m.type});
  return all;
};

const canCross = t => t !== "CHIEF" && t !== "TRADER";

const checkWin = (board, player, piece, dr) => {
  let wC=false, bC=false;
  for (let r=0;r<BOARD_SIZE;r++) for (let c=0;c<BOARD_SIZE;c++)
    if (board[r][c]?.type==="CHIEF") { if(board[r][c].player==="white") wC=true; else bC=true; }
  if (!wC) return "black";
  if (!bC) return "white";
  if (piece && canCross(piece.type)) {
    if (player==="white" && dr===0) return "white";
    if (player==="black" && dr===4) return "black";
  }
  return null;
};

const doMove = (board, m) => {
  const nb = cloneBoard(board);
  const p = {...nb[m.fr][m.fc]};
  let cap = null;
  if (m.mt==="swap") {
    const t = nb[m.tr][m.tc]; nb[m.tr][m.tc]=nb[m.fr][m.fc]; nb[m.fr][m.fc]=t;
  } else {
    cap = nb[m.tr][m.tc];
    nb[m.tr][m.tc]=p; nb[m.fr][m.fc]=null;
  }
  return {board:nb, piece:p, captured:cap};
};

// AI
const PV = {CHIEF:0,KEEPER:900,TRADER:700,HUNTER:500,RIVER_RUNNER:400};

const evaluate = board => {
  let s=0, wC=false, bC=false;
  for (let r=0;r<BOARD_SIZE;r++) for (let c=0;c<BOARD_SIZE;c++) {
    const p=board[r][c]; if(!p) continue;
    if(p.type==="CHIEF"){if(p.player==="white")wC=true;else bC=true;}
    const sign = p.player==="black"?1:-1;
    s += sign * PV[p.type];
    if(canCross(p.type)) s += sign * (p.player==="black"?r:(4-r)) * 18;
    s += sign * (4 - Math.abs(r-2) - Math.abs(c-2)) * 6;
  }
  if(!wC) return 100000; if(!bC) return -100000;
  return s;
};

const minimax = (board, depth, a, b, max) => {
  const moves = getAllMoves(board, max?"black":"white");
  if (depth===0 || moves.length===0) return {score:evaluate(board),move:null};
  let best = moves[0];
  if (max) {
    let mx=-Infinity;
    for (const m of moves) {
      const {board:nb,piece}=doMove(board,m);
      const w=m.mt==="swap"?null:checkWin(nb,"black",piece,m.tr);
      if(w==="black") return {score:100000+depth,move:m};
      if(w==="white") continue;
      const {score}=minimax(nb,depth-1,a,b,false);
      if(score>mx){mx=score;best=m;} a=Math.max(a,score); if(b<=a) break;
    }
    return {score:mx,move:best};
  } else {
    let mn=Infinity;
    for (const m of moves) {
      const {board:nb,piece}=doMove(board,m);
      const w=m.mt==="swap"?null:checkWin(nb,"white",piece,m.tr);
      if(w==="white") return {score:-100000-depth,move:m};
      if(w==="black") continue;
      const {score}=minimax(nb,depth-1,a,b,true);
      if(score<mn){mn=score;best=m;} b=Math.min(b,score); if(b<=a) break;
    }
    return {score:mn,move:best};
  }
};

const DEPTH={1:1,2:2,3:3,4:4,5:5};
const RAND={1:0.4,2:0.2,3:0.08,4:0.02,5:0};

const getAI = (board,diff) => {
  if(Math.random()<RAND[diff]){const ms=getAllMoves(board,"black");return ms.length?ms[Math.floor(Math.random()*ms.length)]:null;}
  return minimax(board,DEPTH[diff],-Infinity,Infinity,true).move;
};

const CL = ["a","b","c","d","e"];
const RL = ["5","4","3","2","1"];
const DL = ["","Beginner","Easy","Medium","Hard","Expert"];

export default function Wachesaw() {
  const [board,setBoard] = useState(createBoard);
  const [sel,setSel] = useState(null);
  const [valid,setValid] = useState([]);
  const [turn,setTurn] = useState("white");
  const [winner,setWinner] = useState(null);
  const [last,setLast] = useState(null);
  const [caps,setCaps] = useState({white:[],black:[]});
  const [log,setLog] = useState([]);
  const [mode,setMode] = useState(null);
  const [diff,setDiff] = useState(3);
  const [thinking,setThinking] = useState(false);
  const [mc,setMc] = useState(0);

  const reset = useCallback(() => {
    setBoard(createBoard()); setSel(null); setValid([]); setTurn("white");
    setWinner(null); setLast(null); setCaps({white:[],black:[]});
    setLog([]); setThinking(false); setMc(0);
  },[]);

  const exec = useCallback((b,fr,fc,tr,tc,mt,player) => {
    const nb=cloneBoard(b); const mp={...nb[fr][fc]}; let logStr="";
    const sym = player==="white"?PIECES[mp.type].symW:PIECES[mp.type].symB;
    const to = CL[tc]+RL[tr];
    if(mt==="swap"){
      const o=nb[tr][tc]; nb[tr][tc]=nb[fr][fc]; nb[fr][fc]=o;
      logStr=`${sym}⇄${to}`;
    } else {
      const cap=nb[tr][tc];
      if(cap){
        setCaps(p=>({...p,[player]:[...p[player],cap.type]}));
        logStr=`${sym}×${to}`;
      } else logStr=`${sym}${to}`;
      nb[tr][tc]=mp; nb[fr][fc]=null;
    }
    setBoard(nb); setLast({fr,fc,tr,tc}); setMc(p=>p+1);
    setLog(p=>[...p,logStr]);
    const w = mt==="swap"?null:checkWin(nb,player,mp,tr);
    if(w){setWinner(w);return{board:nb,winner:w};}
    const next=player==="white"?"black":"white";
    setTurn(next); return{board:nb,winner:null,next};
  },[]);

  const aiMove = useCallback((b,d)=>{
    setThinking(true);
    setTimeout(()=>{
      const m=getAI(b,d);
      if(m) exec(b,m.fr,m.fc,m.tr,m.tc,m.mt,"black");
      setThinking(false);
    },250);
  },[exec]);

  const click = useCallback((r,c)=>{
    if(winner||thinking) return;
    if(mode==="ai"&&turn==="black") return;
    const p=board[r][c];
    if(p&&p.player===turn){
      if(sel?.row===r&&sel?.col===c){setSel(null);setValid([]);return;}
      setSel({row:r,col:c}); setValid(getMoves(board,r,c)); return;
    }
    if(sel){
      const m=valid.find(v=>v.row===r&&v.col===c);
      if(m){
        const res=exec(board,sel.row,sel.col,r,c,m.type,turn);
        setSel(null);setValid([]);
        if(!res.winner&&mode==="ai"&&res.next==="black") aiMove(res.board,diff);
      } else {setSel(null);setValid([]);}
    }
  },[board,sel,valid,turn,winner,mode,thinking,diff,exec,aiMove]);

  const fm = (r,c) => valid.find(v=>v.row===r&&v.col===c);

  // MENU
  if(mode===null) return (
    <div style={{minHeight:"100vh",background:"#312e2b",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",fontFamily:"'Segoe UI',system-ui,sans-serif",color:"#e0e0e0"}}>
      <h1 style={{fontSize:52,fontWeight:200,letterSpacing:8,margin:0,color:"#fff"}}>WACHESAW</h1>
      <p style={{fontSize:12,letterSpacing:4,opacity:0.4,margin:"8px 0 40px 0"}}>HAPPY HUNTING… OR PLACE OF GREAT WEEPING?</p>
      <div style={{display:"flex",flexDirection:"column",gap:10,width:260}}>
        <button onClick={()=>{reset();setMode("ai");}} style={{padding:"14px",background:"#7fa650",color:"#fff",border:"none",borderRadius:6,fontSize:15,fontWeight:600,cursor:"pointer"}}>▶ Play vs AI</button>
        <button onClick={()=>{reset();setMode("local");}} style={{padding:"14px",background:"transparent",color:"#bbb",border:"1px solid #555",borderRadius:6,fontSize:15,cursor:"pointer"}}>👥 Local 2-Player</button>
      </div>
      <div style={{marginTop:28,textAlign:"center"}}>
        <p style={{fontSize:10,opacity:0.4,letterSpacing:2,marginBottom:8}}>AI DIFFICULTY</p>
        <div style={{display:"flex",gap:6,justifyContent:"center"}}>
          {[1,2,3,4,5].map(d=>(
            <button key={d} onClick={()=>setDiff(d)} style={{
              width:42,height:42,borderRadius:6,fontSize:16,cursor:"pointer",
              background:d===diff?"#7fa650":"rgba(255,255,255,0.05)",
              color:d===diff?"#fff":"#888",border:d===diff?"none":"1px solid #555",
              fontWeight:d===diff?700:400,
            }}>{d}</button>
          ))}
        </div>
        <p style={{fontSize:10,opacity:0.35,marginTop:4}}>{DL[diff]}</p>
      </div>
      <div style={{marginTop:40,maxWidth:340,textAlign:"center",opacity:0.3,fontSize:11,lineHeight:1.8}}>
        Capture the opponent's King (♔/♚) or reach their back row. Swap adjacent friendly pieces. Knight can't cross-win.
      </div>
    </div>
  );

  // GAME
  return (
    <div style={{minHeight:"100vh",background:"#312e2b",display:"flex",flexDirection:"column",alignItems:"center",padding:16,fontFamily:"'Segoe UI',system-ui,sans-serif",color:"#e0e0e0"}}>
      <div style={{display:"flex",alignItems:"center",gap:16,marginBottom:10,width:"100%",maxWidth:600,justifyContent:"space-between"}}>
        <button onClick={()=>{setMode(null);reset();}} style={{background:"none",border:"none",color:"#888",cursor:"pointer",fontSize:13}}>← Menu</button>
        <span style={{fontSize:18,fontWeight:200,letterSpacing:4,color:"#fff"}}>WACHESAW</span>
        <span style={{fontSize:11,opacity:0.4}}>{mode==="ai"?`AI ${DL[diff]}`:"Local"}</span>
      </div>

      <div style={{
        background:winner?"rgba(127,166,80,0.12)":"rgba(255,255,255,0.04)",
        border:`1px solid ${winner?"#7fa650":"#3d3a37"}`,
        borderRadius:6,padding:"5px 18px",marginBottom:10,fontSize:13,textAlign:"center",
      }}>
        {winner ? <span style={{color:"#7fa650",fontWeight:600}}>{winner==="white"?"White":"Black"} wins! {mode==="ai"?(winner==="white"?"Happy Hunting!":"Place of Great Weeping…"):""}</span>
         : thinking ? <span style={{opacity:0.4}}>AI thinking…</span>
         : <span>{turn==="white"?"⬜ White":"⬛ Black"} to move</span>}
      </div>

      <div style={{display:"flex",gap:16,alignItems:"flex-start",flexWrap:"wrap",justifyContent:"center"}}>
        <div>
          <div style={{height:24,display:"flex",gap:2,paddingLeft:22,fontSize:17,opacity:0.5}}>
            {caps.black.map((t,i)=><span key={i}>{PIECES[t].symW}</span>)}
          </div>
          <div style={{display:"flex"}}>
            <div style={{display:"flex",flexDirection:"column",justifyContent:"space-around",paddingRight:4,width:18}}>
              {RL.map(l=><span key={l} style={{fontSize:10,opacity:0.25,textAlign:"right"}}>{l}</span>)}
            </div>
            <div style={{
              display:"grid",gridTemplateColumns:`repeat(5,68px)`,gridTemplateRows:`repeat(5,68px)`,
              border:"2px solid #3d3a37",borderRadius:2,overflow:"hidden",boxShadow:"0 4px 20px rgba(0,0,0,0.5)",
            }}>
              {Array(25).fill(0).map((_,i)=>{
                const r=Math.floor(i/5),c=i%5;
                const p=board[r][c];
                const light=(r+c)%2===0;
                const isSel=sel?.row===r&&sel?.col===c;
                const mi=fm(r,c);
                const isLM=last&&((last.fr===r&&last.fc===c)||(last.tr===r&&last.tc===c));

                let bg = light?"#f0d9b5":"#b58863";
                if(isLM&&!isSel&&!mi) bg=light?"#f7ec7a":"#dac534";
                if(isSel) bg=light?"#6db4e8":"#4a90c0";
                if(mi){
                  if(mi.type==="move"&&p) bg=light?"#f09090":"#c86060";
                  else if(mi.type==="swap") bg=light?"#90c0e8":"#6898c0";
                  else if(mi.type==="move") bg=light?"#cce8a0":"#9cc068";
                }

                return (
                  <div key={i} onClick={()=>click(r,c)} style={{
                    width:68,height:68,background:bg,display:"flex",alignItems:"center",justifyContent:"center",
                    cursor:(!winner&&!thinking&&(p?.player===turn||mi))?"pointer":"default",position:"relative",
                  }}>
                    {mi&&!p&&mi.type==="move"&&<div style={{width:17,height:17,borderRadius:"50%",background:"rgba(0,0,0,0.2)"}}/>}
                    {mi&&mi.type==="swap"&&<div style={{position:"absolute",top:2,right:4,fontSize:9,opacity:0.6,color:"#1a5090",fontWeight:700}}>⇄</div>}
                    {p&&<span style={{fontSize:42,lineHeight:1,userSelect:"none",filter:isSel?"drop-shadow(0 0 8px rgba(100,180,255,0.6))":"none"}}>{p.player==="white"?PIECES[p.type].symW:PIECES[p.type].symB}</span>}
                    {mi&&p&&mi.type==="move"&&<div style={{position:"absolute",inset:2,border:"3px solid rgba(170,30,30,0.55)"}}/>}
                  </div>
                );
              })}
            </div>
          </div>
          <div style={{display:"flex",paddingLeft:22,marginTop:2}}>
            {CL.map(l=><span key={l} style={{width:68,textAlign:"center",fontSize:10,opacity:0.25}}>{l}</span>)}
          </div>
          <div style={{height:24,marginTop:2,display:"flex",gap:2,paddingLeft:22,fontSize:17,opacity:0.5}}>
            {caps.white.map((t,i)=><span key={i}>{PIECES[t].symB}</span>)}
          </div>
          <div style={{display:"flex",gap:6,marginTop:8}}>
            <button onClick={reset} style={{flex:1,padding:7,background:"rgba(255,255,255,0.05)",border:"1px solid #3d3a37",color:"#999",borderRadius:4,cursor:"pointer",fontSize:11}}>New Game</button>
            {mode==="ai"&&<select value={diff} onChange={e=>{setDiff(Number(e.target.value));reset();}} style={{padding:"7px 10px",background:"#272522",border:"1px solid #3d3a37",color:"#999",borderRadius:4,fontSize:11}}>
              {[1,2,3,4,5].map(d=><option key={d} value={d}>Lv.{d} {DL[d]}</option>)}
            </select>}
          </div>
        </div>

        <div style={{width:185,fontSize:11}}>
          <div style={{background:"#272522",border:"1px solid #3d3a37",borderRadius:6,padding:10,marginBottom:8}}>
            <h3 style={{fontSize:9,letterSpacing:2,textTransform:"uppercase",margin:"0 0 5px 0",opacity:0.35}}>Pieces</h3>
            {Object.entries(PIECES).map(([k,p])=>(
              <div key={k} style={{padding:"2px 0",borderBottom:"1px solid #3d3a37"}}>
                <span style={{fontSize:15}}>{p.symW}{p.symB}</span>
                <span style={{marginLeft:4,fontWeight:600,fontSize:10}}>{p.name}</span>
                <div style={{fontSize:9,opacity:0.4,marginLeft:1}}>{p.desc}</div>
              </div>
            ))}
          </div>
          <div style={{background:"#272522",border:"1px solid #3d3a37",borderRadius:6,padding:10,marginBottom:8}}>
            <h3 style={{fontSize:9,letterSpacing:2,textTransform:"uppercase",margin:"0 0 5px 0",opacity:0.35}}>Win Conditions</h3>
            <div style={{fontSize:9,opacity:0.45,lineHeight:1.7}}>
              <p style={{margin:"0 0 3px"}}>👑 Capture opponent's Chief</p>
              <p style={{margin:"0 0 3px"}}>🏁 Reach their back row</p>
              <p style={{margin:"0 0 3px"}}>⇄ Swap = valid move</p>
              <p style={{margin:0}}>🚫 Trader/Chief can't cross</p>
            </div>
          </div>
          <div style={{background:"#272522",border:"1px solid #3d3a37",borderRadius:6,padding:10,maxHeight:200,overflowY:"auto"}}>
            <h3 style={{fontSize:9,letterSpacing:2,textTransform:"uppercase",margin:"0 0 5px 0",opacity:0.35}}>Moves</h3>
            {log.length===0?<p style={{fontSize:9,opacity:0.25,margin:0}}>White opens.</p>
            :<div style={{display:"grid",gridTemplateColumns:"16px 1fr 1fr",gap:"1px 4px",fontSize:10}}>
              {Array(Math.ceil(log.length/2)).fill(0).map((_,i)=>(
                <div key={i} style={{display:"contents"}}>
                  <span style={{opacity:0.25}}>{i+1}</span>
                  <span style={{opacity:0.65}}>{log[i*2]||""}</span>
                  <span style={{opacity:0.45}}>{log[i*2+1]||""}</span>
                </div>
              ))}
            </div>}
          </div>
        </div>
      </div>
    </div>
  );
}
