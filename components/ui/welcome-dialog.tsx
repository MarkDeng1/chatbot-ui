import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { useState, useEffect } from "react"

const emotions = [
  { label: "Very Happy", value: 5, emoji: "😄" },
  { label: "Happy", value: 4, emoji: "🙂" },
  { label: "Neutral", value: 3, emoji: "😐" },
  { label: "Sad", value: 2, emoji: "😔" },
  { label: "Very Sad", value: 1, emoji: "😢" }
]

export function WelcomeDialog() {
  const [open, setOpen] = useState(false)
  const [selectedEmotion, setSelectedEmotion] = useState<number | null>(null)

  useEffect(() => {
    // 添加调试日志
    console.log("WelcomeDialog mounted")

    // 检查是否是首次登录
    const hasSeenWelcome = localStorage.getItem("hasSeenWelcome")
    console.log("hasSeenWelcome:", hasSeenWelcome)

    // 强制显示弹窗（用于测试）
    setOpen(true)

    // 设置标记
    localStorage.setItem("hasSeenWelcome", "true")
  }, [])

  const handleEmotionSelect = (value: number) => {
    setSelectedEmotion(value)
    // 这里可以添加选择情绪后的处理逻辑
    console.log("Selected emotion:", value)
    // 选择情绪后自动关闭弹窗
    setOpen(false)
  }

  return (
    <Dialog open={open} onOpenChange={() => {}}>
      <DialogContent
        className="sm:max-w-[425px]"
        onPointerDownOutside={e => e.preventDefault()}
      >
        <DialogHeader>
          <DialogTitle>Welcome to Chat!</DialogTitle>
          <DialogDescription>Emo Survey 1/3</DialogDescription>
          <p className="text-muted-foreground mt-2 text-sm">
            Before start, you need to record your current state.
          </p>
        </DialogHeader>
        <div className="grid gap-4 py-4">
          <div className="flex flex-col gap-2">
            {emotions.map(emotion => (
              <Button
                key={emotion.value}
                variant={
                  selectedEmotion === emotion.value ? "default" : "outline"
                }
                className="w-full justify-start text-lg"
                onClick={() => handleEmotionSelect(emotion.value)}
              >
                <span className="mr-2">{emotion.emoji}</span>
                {emotion.label}
              </Button>
            ))}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
