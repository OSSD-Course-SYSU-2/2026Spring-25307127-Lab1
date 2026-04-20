// Index.ets - 猜数字游戏
@Entry
@Component
struct GuessNumber {
  @State targetNumber: number = 0;      // 要猜的数字
  @State guessInput: string = '';       // 输入框内容
  @State message: string = '输入 1-100 之间的数字';  // 提示信息
  @State remainingAttempts: number = 10; // 剩余次数
  @State gameOver: boolean = false;

  aboutToAppear(): void {
    this.newGame();
  }

  // 开始新游戏
  newGame(): void {
    this.targetNumber = Math.floor(Math.random() * 100) + 1; // 1-100 随机数
    this.guessInput = '';
    this.message = '新游戏！输入 1-100 之间的数字';
    this.remainingAttempts = 10;
    this.gameOver = false;
  }

  // 处理猜数
  submitGuess(): void {
    if (this.gameOver) {
      this.message = '游戏已结束，请点击“新游戏”';
      return;
    }

    const guess = parseInt(this.guessInput);
    if (isNaN(guess) || guess < 1 || guess > 100) {
      this.message = '请输入 1-100 的有效数字';
      return;
    }

    this.remainingAttempts--;
    if (guess === this.targetNumber) {
      this.message = `🎉 恭喜！猜中了！数字就是 ${this.targetNumber} 🎉`;
      this.gameOver = true;
    } else if (this.remainingAttempts === 0) {
      this.message = `😭 次数用完了！数字是 ${this.targetNumber}。点击“新游戏”继续`;
      this.gameOver = true;
    } else if (guess < this.targetNumber) {
      this.message = `📈 小了！还剩 ${this.remainingAttempts} 次机会`;
    } else {
      this.message = `📉 大了！还剩 ${this.remainingAttempts} 次机会`;
    }
    this.guessInput = ''; // 清空输入框
  }

  build() {
    Column({ space: 20 }) {
      Text('🔢 猜数字游戏')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 30 })

      Text(this.message)
        .fontSize(18)
        .fontColor(this.gameOver ? Color.Orange : Color.Black)
        .textAlign(TextAlign.Center)
        .padding(10)

      Text(`剩余次数: ${this.remainingAttempts}`)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)

      Row({ space: 10 }) {
        TextInput({ placeholder: '输入数字', text: this.guessInput })
          .width(150)
          .onChange((value: string) => { this.guessInput = value })
          .enabled(!this.gameOver)

        Button('猜')
          .onClick(() => this.submitGuess())
          .enabled(!this.gameOver)
      }

      Button('新游戏')
        .onClick(() => this.newGame())
        .backgroundColor(Color.Green)
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(20)
  }
}