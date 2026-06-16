// 贪吃蛇游戏 - 多端适配最终版（无路由依赖，支持手机/平板/折叠屏/2in1）
import { mediaquery } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';

interface SnakePos {
  x: number;
  y: number;
}

type SnakeDir = 'UP' | 'DOWN' | 'LEFT' | 'RIGHT';
type Breakpoint = 'sm' | 'md' | 'lg' | 'xl';

@Entry
@Component
struct SnakeGameFinal {
  // 游戏配置
  private readonly gridSize: number = 20;
  private readonly initSnake: SnakePos[] = [
    { x: 10, y: 10 }, { x: 9, y: 10 }, { x: 8, y: 10 }, { x: 7, y: 10 }
  ];

  @State snake: SnakePos[] = [];
  @State food: SnakePos = { x: 15, y: 10 };
  @State currentDir: SnakeDir = 'RIGHT';
  @State nextDir: SnakeDir = 'RIGHT';
  @State score: number = 0;
  @State highScore: number = 0;
  @State gameOver: boolean = false;
  @State isRunning: boolean = true;
  @State isPaused: boolean = false;
  @State currentSpeed: number = 150;
  @State difficulty: string = '普通';
  @State wallPass: boolean = false;

  // 多端适配相关
  @State curBreakpoint: Breakpoint = 'sm';
  @State canvasSize: number = 400;
  @State cellSize: number = 20;
  private mediaListenerMd: mediaquery.MediaQueryListener | null = null;
  private mediaListenerLg: mediaquery.MediaQueryListener | null = null;
  private mediaListenerXl: mediaquery.MediaQueryListener | null = null;

  @State showScorePopup: boolean = false;
  @State popupText: string = '';

  private gameInterval: number = -1;
  private dataPreferences: preferences.Preferences | null = null;
  private popupTimer: number = -1;
  private foodPulse: number = 0;
  private pulseDirection: number = 1;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.initMediaQuery();
    this.loadHighScore();
    this.initGame();
    this.startBreathing();
  }

  aboutToDisappear(): void {
    if (this.gameInterval !== -1) clearInterval(this.gameInterval);
    if (this.popupTimer !== -1) clearTimeout(this.popupTimer);
    this.mediaListenerMd?.off('change');
    this.mediaListenerLg?.off('change');
    this.mediaListenerXl?.off('change');
  }

  initMediaQuery(): void {
    this.mediaListenerMd = mediaquery.matchMediaSync('(min-width: 600vp)');
    this.mediaListenerLg = mediaquery.matchMediaSync('(min-width: 840vp)');
    this.mediaListenerXl = mediaquery.matchMediaSync('(min-width: 1200vp)');

    const updateBreakpoint = () => {
      if (this.mediaListenerXl?.matches) this.curBreakpoint = 'xl';
      else if (this.mediaListenerLg?.matches) this.curBreakpoint = 'lg';
      else if (this.mediaListenerMd?.matches) this.curBreakpoint = 'md';
      else this.curBreakpoint = 'sm';
      this.updateCanvasSize();
    };

    this.mediaListenerMd.on('change', () => updateBreakpoint());
    this.mediaListenerLg.on('change', () => updateBreakpoint());
    this.mediaListenerXl.on('change', () => updateBreakpoint());
    updateBreakpoint();
  }

  updateCanvasSize(): void {
    let maxSize = 380;
    switch (this.curBreakpoint) {
      case 'sm': maxSize = 380; break;
      case 'md': maxSize = 500; break;
      case 'lg': maxSize = 600; break;
      case 'xl': maxSize = 700; break;
    }
    this.canvasSize = maxSize;
    this.cellSize = this.canvasSize / this.gridSize;
    if (this.context) this.drawGame();
  }

  async loadHighScore(): Promise<void> {
    try {
      this.dataPreferences = await preferences.getPreferences(getContext(this), 'snake_prefs');
      this.highScore = await this.dataPreferences.get('highScore', 0) as number;
    } catch (err) {
      console.error('加载最高分失败', err);
    }
  }

  async saveHighScore(): Promise<void> {
    if (this.score > this.highScore) {
      this.highScore = this.score;
      if (this.dataPreferences) {
        await this.dataPreferences.put('highScore', this.highScore);
        await this.dataPreferences.flush();
      }
    }
  }

  initGame(): void {
    this.snake = JSON.parse(JSON.stringify(this.initSnake));
    this.currentDir = 'RIGHT';
    this.nextDir = 'RIGHT';
    this.score = 0;
    this.gameOver = false;
    this.isRunning = true;
    this.isPaused = false;
    this.updateSpeedByDifficulty();
    if (this.gameInterval !== -1) clearInterval(this.gameInterval);
    this.generateRandomFood();
    this.startGameLoop();
    this.drawGame();
  }

  updateSpeedByDifficulty(): void {
    switch (this.difficulty) {
      case '简单': this.currentSpeed = 200; break;
      case '普通': this.currentSpeed = 150; break;
      case '困难': this.currentSpeed = 100; break;
      default: this.currentSpeed = 150;
    }
  }

  startGameLoop(): void {
    if (this.gameInterval !== -1) clearInterval(this.gameInterval);
    this.gameInterval = setInterval(() => {
      if (!this.isRunning || this.gameOver || this.isPaused) return;
      this.gameTick();
    }, this.currentSpeed);
  }

  gameTick(): void {
    const newDir = this.getValidDirection();
    this.currentDir = newDir;

    const head = this.snake[0];
    let newHead: SnakePos = { x: head.x, y: head.y };
    switch (this.currentDir) {
      case 'UP': newHead.y--; break;
      case 'DOWN': newHead.y++; break;
      case 'LEFT': newHead.x--; break;
      case 'RIGHT': newHead.x++; break;
    }

    if (this.wallPass) {
      if (newHead.x < 0) newHead.x = this.gridSize - 1;
      if (newHead.x >= this.gridSize) newHead.x = 0;
      if (newHead.y < 0) newHead.y = this.gridSize - 1;
      if (newHead.y >= this.gridSize) newHead.y = 0;
    }

    const willEat = (newHead.x === this.food.x && newHead.y === this.food.y);
    if (willEat) {
      this.snake = [newHead, ...this.snake];
      this.score++;
      this.showScorePopupText(`+${this.score}`);
      this.generateRandomFood();
      this.saveHighScore();
    } else {
      this.snake = [newHead, ...this.snake.slice(0, -1)];
    }

    if (this.checkCollision()) {
      this.gameOver = true;
      this.isRunning = false;
      if (this.gameInterval !== -1) clearInterval(this.gameInterval);
      this.saveHighScore();
    }
    this.drawGame();
  }

  getValidDirection(): SnakeDir {
    const nd = this.nextDir;
    if ((nd === 'UP' && this.currentDir === 'DOWN') ||
      (nd === 'DOWN' && this.currentDir === 'UP') ||
      (nd === 'LEFT' && this.currentDir === 'RIGHT') ||
      (nd === 'RIGHT' && this.currentDir === 'LEFT')) {
      return this.currentDir;
    }
    return nd;
  }

  checkCollision(): boolean {
    const head = this.snake[0];
    if (!this.wallPass) {
      if (head.x < 0 || head.x >= this.gridSize || head.y < 0 || head.y >= this.gridSize) return true;
    }
    for (let i = 1; i < this.snake.length; i++) {
      if (this.snake[i].x === head.x && this.snake[i].y === head.y) return true;
    }
    return false;
  }

  generateRandomFood(): void {
    const totalCells = this.gridSize * this.gridSize;
    if (this.snake.length >= totalCells) {
      this.gameOver = true;
      this.isRunning = false;
      if (this.gameInterval !== -1) clearInterval(this.gameInterval);
      return;
    }
    const snakeSet = new Set(this.snake.map(p => `${p.x},${p.y}`));
    const freeCells: SnakePos[] = [];
    for (let i = 0; i < this.gridSize; i++) {
      for (let j = 0; j < this.gridSize; j++) {
        if (!snakeSet.has(`${i},${j}`)) freeCells.push({ x: i, y: j });
      }
    }
    if (freeCells.length > 0) {
      const rand = Math.floor(Math.random() * freeCells.length);
      this.food = freeCells[rand];
    }
  }

  changeDirection(newDir: SnakeDir): void {
    if (this.gameOver || !this.isRunning || this.isPaused) return;
    this.nextDir = newDir;
  }

  restart(): void {
    if (this.gameInterval !== -1) clearInterval(this.gameInterval);
    this.initGame();
  }

  pauseResume(): void {
    if (this.gameOver) return;
    this.isPaused = !this.isPaused;
    if (!this.isPaused) this.drawGame();
  }

  adjustSpeed(delta: number): void {
    if (this.gameOver || this.isPaused) return;
    let newSpeed = this.currentSpeed + delta;
    if (newSpeed < 50) newSpeed = 50;
    if (newSpeed > 400) newSpeed = 400;
    this.currentSpeed = newSpeed;
    this.startGameLoop();
    this.drawGame();
  }

  setDifficulty(level: string): void {
    this.difficulty = level;
    this.updateSpeedByDifficulty();
    if (!this.gameOver && this.isRunning && !this.isPaused) this.startGameLoop();
  }

  toggleWallPass(): void {
    this.wallPass = !this.wallPass;
    this.drawGame();
  }

  showScorePopupText(text: string): void {
    this.popupText = text;
    this.showScorePopup = true;
    if (this.popupTimer !== -1) clearTimeout(this.popupTimer);
    this.popupTimer = setTimeout(() => {
      this.showScorePopup = false;
    }, 500);
  }

  startBreathing(): void {
    setInterval(() => {
      if (!this.gameOver && this.isRunning) {
        this.foodPulse += this.pulseDirection * 0.05;
        if (this.foodPulse >= 1) { this.foodPulse = 1; this.pulseDirection = -1; }
        if (this.foodPulse <= 0.5) { this.foodPulse = 0.5; this.pulseDirection = 1; }
        this.drawGame();
      }
    }, 100);
  }

  drawGame(): void {
    if (!this.context) return;
    this.context.clearRect(0, 0, this.canvasSize, this.canvasSize);
    // 网格
    this.context.strokeStyle = '#AAAAAA';
    this.context.lineWidth = 0.5;
    for (let i = 0; i <= this.gridSize; i++) {
      this.context.beginPath();
      this.context.moveTo(i * this.cellSize, 0);
      this.context.lineTo(i * this.cellSize, this.canvasSize);
      this.context.stroke();
      this.context.beginPath();
      this.context.moveTo(0, i * this.cellSize);
      this.context.lineTo(this.canvasSize, i * this.cellSize);
      this.context.stroke();
    }
    // 食物呼吸
    const pulseScale = 0.8 + this.foodPulse * 0.4;
    const offset = (this.cellSize - this.cellSize * pulseScale) / 2;
    this.context.fillStyle = '#FF4444';
    this.context.fillRect(
      this.food.x * this.cellSize + offset,
      this.food.y * this.cellSize + offset,
      this.cellSize * pulseScale,
      this.cellSize * pulseScale
    );
    // 蛇身
    this.context.fillStyle = '#44AA44';
    for (let i = 0; i < this.snake.length; i++) {
      const seg = this.snake[i];
      this.context.fillRect(seg.x * this.cellSize, seg.y * this.cellSize, this.cellSize, this.cellSize);
    }
    // 蛇头
    const head = this.snake[0];
    if (head) {
      this.context.fillStyle = '#66DD66';
      this.context.fillRect(head.x * this.cellSize, head.y * this.cellSize, this.cellSize, this.cellSize);
      this.context.strokeStyle = '#006600';
      this.context.lineWidth = 2;
      this.context.strokeRect(head.x * this.cellSize, head.y * this.cellSize, this.cellSize, this.cellSize);
    }
    if (this.wallPass) {
      this.context.font = '14px sans-serif';
      this.context.fillStyle = '#FF6600';
      this.context.fillText('穿墙模式', 10, 30);
    }
    if (this.isPaused && !this.gameOver) {
      this.context.font = 'bold 24px sans-serif';
      this.context.fillStyle = '#333333';
      this.context.fillText('暂停', this.canvasSize/2-40, this.canvasSize/2);
    }
  }

  @Builder
  ControlPanel() {
    Column() {
      Row() {
        Column() {
          Text(`得分: ${this.score}`).fontSize(this.curBreakpoint === 'sm' ? 18 : 22).fontWeight(FontWeight.Bold)
          Text(`最高: ${this.highScore}`).fontSize(14).fontColor('#666')
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Button(this.isPaused ? '继续' : '暂停').onClick(() => this.pauseResume()).margin(5)
        Button('新游戏').onClick(() => this.restart()).margin(5)
      }
      .width('100%')
      .padding(10)

      Row() {
        Button('减速').onClick(() => this.adjustSpeed(20)).backgroundColor('#FF9800')
        Text(`速度: ${Math.round(1000/this.currentSpeed)}步/秒`).fontSize(14).margin({ left: 10, right: 10 })
        Button('加速').onClick(() => this.adjustSpeed(-20)).backgroundColor('#FF9800')
      }
      .margin({ top: 5 }).justifyContent(FlexAlign.Center)

      Row() {
        Text('难度:').fontSize(16)
        ForEach(['简单', '普通', '困难'], (level: string) => {
          Button(level)
            .backgroundColor(this.difficulty === level ? '#4CAF50' : '#CCCCCC')
            .margin({ left: 5, right: 5 })
            .onClick(() => this.setDifficulty(level))
        })
      }
      .margin({ top: 5 }).justifyContent(FlexAlign.Center)

      Row() {
        Text('穿墙模式').fontSize(16)
        Toggle({ type: ToggleType.Switch, isOn: this.wallPass })
          .onChange((isOn: boolean) => { this.wallPass = isOn })
          .margin({ left: 10 })
      }
      .margin({ top: 5 }).justifyContent(FlexAlign.Center)

      Column() {
        Row() { Button('↑').width(70).height(70).fontSize(30).onClick(() => this.changeDirection('UP')) }
        .justifyContent(FlexAlign.Center).width('100%').margin({ top: 5 })
        Row({ space: 20 }) {
          Button('←').width(70).height(70).fontSize(30).onClick(() => this.changeDirection('LEFT'))
          Button('↓').width(70).height(70).fontSize(30).onClick(() => this.changeDirection('DOWN'))
          Button('→').width(70).height(70).fontSize(30).onClick(() => this.changeDirection('RIGHT'))
        }.justifyContent(FlexAlign.Center).width('100%').margin({ top: 5 })
      }
      .margin({ top: 10, bottom: 10 })
    }
    .width('100%')
  }

  build() {
    if (this.curBreakpoint === 'sm') {
      Column() {
        this.ControlPanel();
        Canvas(this.context)
          .width(this.canvasSize)
          .height(this.canvasSize)
          .backgroundColor('#F0F0F0')
          .onReady(() => { this.updateCanvasSize(); this.drawGame(); })
          .margin({ top: 10, bottom: 10 });
        if (this.showScorePopup) {
          Text(this.popupText)
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#FF6600')
            .position({ x: this.canvasSize/2 - 30, y: this.canvasSize/2 - 40 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F8F8F8')
      .alignItems(HorizontalAlign.Center)
    } else {
      Row() {
        Column() {
          Canvas(this.context)
            .width(this.canvasSize)
            .height(this.canvasSize)
            .backgroundColor('#F0F0F0')
            .onReady(() => { this.updateCanvasSize(); this.drawGame(); })
          if (this.showScorePopup) {
            Text(this.popupText)
              .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#FF6600')
              .position({ x: this.canvasSize/2 - 30, y: this.canvasSize/2 - 40 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column() {
          this.ControlPanel();
        }
        .width('30%')
        .padding(10)
        .backgroundColor('#F0F0F0')
        .height('100%')
      }
      .width('100%').height('100%').backgroundColor('#F8F8F8')
    }
  }
}