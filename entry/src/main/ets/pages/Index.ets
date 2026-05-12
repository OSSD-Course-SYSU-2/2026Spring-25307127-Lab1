// 贪吃蛇游戏 - Canvas 版（稳定显示）
interface SnakePos {
  x: number;
  y: number;
}

type SnakeDir = 'UP' | 'DOWN' | 'LEFT' | 'RIGHT';

@Entry
@Component
struct SnakeGameCanvas {
  // 游戏配置
  private readonly gridSize: number = 20;    // 20x20 网格
  private readonly cellSize: number = 20;    // 每个格子 20px
  private readonly canvasWidth: number = 400; // 20*20 = 400px
  private readonly canvasHeight: number = 400;
  private readonly initSnake: SnakePos[] = [
    { x: 10, y: 10 },
    { x: 9, y: 10 },
    { x: 8, y: 10 },
    { x: 7, y: 10 }
  ];

  @State snake: SnakePos[] = [];
  @State food: SnakePos = { x: 15, y: 10 };
  @State currentDir: SnakeDir = 'RIGHT';
  @State nextDir: SnakeDir = 'RIGHT';
  @State score: number = 0;
  @State gameOver: boolean = false;
  @State isRunning: boolean = true;
  private gameInterval: number = -1;
  private readonly speedMs: number = 150;

  // Canvas 相关
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.initGame();
  }

  aboutToDisappear(): void {
    if (this.gameInterval !== -1) {
      clearInterval(this.gameInterval);
    }
  }

  initGame(): void {
    this.snake = JSON.parse(JSON.stringify(this.initSnake));
    this.currentDir = 'RIGHT';
    this.nextDir = 'RIGHT';
    this.score = 0;
    this.gameOver = false;
    this.isRunning = true;
    if (this.gameInterval !== -1) {
      clearInterval(this.gameInterval);
    }
    this.generateRandomFood();
    this.startGameLoop();
    this.drawGame(); // 立即绘制一次
  }

  startGameLoop(): void {
    this.gameInterval = setInterval(() => {
      if (!this.isRunning || this.gameOver) return;
      this.gameTick();
    }, this.speedMs);
  }

  gameTick(): void {
    // 应用方向
    const newDir = this.getValidDirection();
    this.currentDir = newDir;

    // 计算新头
    const head = this.snake[0];
    let newHead: SnakePos = { x: head.x, y: head.y };
    switch (this.currentDir) {
      case 'UP': newHead.y--; break;
      case 'DOWN': newHead.y++; break;
      case 'LEFT': newHead.x--; break;
      case 'RIGHT': newHead.x++; break;
    }

    const willEat = (newHead.x === this.food.x && newHead.y === this.food.y);

    if (willEat) {
      this.snake = [newHead, ...this.snake];
      this.score++;
      this.generateRandomFood();
    } else {
      this.snake = [newHead, ...this.snake.slice(0, -1)];
    }

    if (this.checkCollision()) {
      this.gameOver = true;
      this.isRunning = false;
      if (this.gameInterval !== -1) {
        clearInterval(this.gameInterval);
        this.gameInterval = -1;
      }
    }

    // 每次更新后重绘
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
    if (head.x < 0 || head.x >= this.gridSize || head.y < 0 || head.y >= this.gridSize) {
      return true;
    }
    for (let i = 1; i < this.snake.length; i++) {
      if (this.snake[i].x === head.x && this.snake[i].y === head.y) {
        return true;
      }
    }
    return false;
  }

  generateRandomFood(): void {
    const totalCells = this.gridSize * this.gridSize;
    if (this.snake.length >= totalCells) {
      this.gameOver = true;
      this.isRunning = false;
      if (this.gameInterval !== -1) {
        clearInterval(this.gameInterval);
        this.gameInterval = -1;
      }
      return;
    }

    const snakeSet = new Set(this.snake.map(p => `${p.x},${p.y}`));
    const freeCells: SnakePos[] = [];
    for (let i = 0; i < this.gridSize; i++) {
      for (let j = 0; j < this.gridSize; j++) {
        if (!snakeSet.has(`${i},${j}`)) {
          freeCells.push({ x: i, y: j });
        }
      }
    }
    if (freeCells.length > 0) {
      const rand = Math.floor(Math.random() * freeCells.length);
      this.food = freeCells[rand];
    }
  }

  changeDirection(newDir: SnakeDir): void {
    if (this.gameOver || !this.isRunning) return;
    this.nextDir = newDir;
  }

  restart(): void {
    // 清理旧循环
    if (this.gameInterval !== -1) {
      clearInterval(this.gameInterval);
      this.gameInterval = -1;
    }
    this.initGame();
  }

  // 绘制整个游戏
  drawGame(): void {
    if (!this.context) return;
    // 清空画布
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    // 绘制网格线（浅灰）
    this.context.strokeStyle = '#AAAAAA';
    this.context.lineWidth = 0.5;
    for (let i = 0; i <= this.gridSize; i++) {
      this.context.beginPath();
      this.context.moveTo(i * this.cellSize, 0);
      this.context.lineTo(i * this.cellSize, this.canvasHeight);
      this.context.stroke();
      this.context.beginPath();
      this.context.moveTo(0, i * this.cellSize);
      this.context.lineTo(this.canvasWidth, i * this.cellSize);
      this.context.stroke();
    }
    // 绘制食物
    this.context.fillStyle = '#FF0000';
    this.context.fillRect(this.food.x * this.cellSize, this.food.y * this.cellSize, this.cellSize, this.cellSize);
    // 绘制蛇
    this.context.fillStyle = '#00AA00';
    for (const seg of this.snake) {
      this.context.fillRect(seg.x * this.cellSize, seg.y * this.cellSize, this.cellSize, this.cellSize);
    }
    // 绘制蛇头边框（可选）
    const head = this.snake[0];
    if (head) {
      this.context.strokeStyle = '#006600';
      this.context.lineWidth = 2;
      this.context.strokeRect(head.x * this.cellSize, head.y * this.cellSize, this.cellSize, this.cellSize);
    }
  }

  build() {
    Column() {
      // 顶部信息栏
      Row() {
        Text(`得分: ${this.score}`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin(10)
        Blank()
        if (this.gameOver) {
          Text('游戏结束')
            .fontSize(24)
            .fontColor(Color.Red)
            .margin(10)
        }
        Button('新游戏')
          .onClick(() => this.restart())
          .margin(10)
      }
      .width('100%')
      .padding(10)

      // Canvas 画布
      Canvas(this.context)
        .width(this.canvasWidth)
        .height(this.canvasHeight)
        .backgroundColor('#F0F0F0')
        .onReady(() => {
          // Canvas 准备就绪后绘制初始画面
          this.drawGame();
        })
        .margin({ top: 20 })

      // 方向按钮
      Column() {
        Row() {
          Button('↑')
            .width(80)
            .height(80)
            .fontSize(40)
            .onClick(() => this.changeDirection('UP'))
        }.justifyContent(FlexAlign.Center).width('100%').margin({ top: 10 })

        Row({ space: 40 }) {
          Button('←')
            .width(80)
            .height(80)
            .fontSize(40)
            .onClick(() => this.changeDirection('LEFT'))
          Button('↓')
            .width(80)
            .height(80)
            .fontSize(40)
            .onClick(() => this.changeDirection('DOWN'))
          Button('→')
            .width(80)
            .height(80)
            .fontSize(40)
            .onClick(() => this.changeDirection('RIGHT'))
        }.justifyContent(FlexAlign.Center).width('100%').margin({ top: 10, bottom: 30 })
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }
}