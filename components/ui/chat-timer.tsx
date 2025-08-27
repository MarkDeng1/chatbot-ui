import { useContext, useEffect, useState, useCallback } from "react"
import { ChatbotUIContext } from "@/context/context"
import { WelcomeDialog } from "./welcome-dialog"
import { ActivityTracker } from "./activity-tracker"

interface ChatTimerProps {
  onSurveyNeeded: (surveyOrder: number) => void
}

export function ChatTimer({ onSurveyNeeded }: ChatTimerProps) {
  const [isActive, setIsActive] = useState(false)
  const [isOnline, setIsOnline] = useState(false)
  const [lastActivityTime, setLastActivityTime] = useState(Date.now())
  const [sessionStartTime, setSessionStartTime] = useState<number | null>(null)
  const [nextSurveyTime, setNextSurveyTime] = useState<number | null>(null)
  const [currentSurveyOrder, setCurrentSurveyOrder] = useState(1)
  const [showSurvey, setShowSurvey] = useState(false)
  const [dailySurveyCompleted, setDailySurveyCompleted] = useState(false)

  const { profile, chatMessages } = useContext(ChatbotUIContext)

  // 检查每日首次survey状态
  const checkDailySurveyStatus = useCallback(async () => {
    if (!profile?.user_id) {
      console.log("No profile user_id available")
      return
    }

    try {
      const response = await fetch(
        `/api/emoji-survey?userId=${profile.user_id}`
      )
      const data = await response.json()

      console.log("Survey status response:", data)

      if (data.error && data.error.includes("Invalid userId format")) {
        // UUID格式错误，显示首次survey让用户可以尝试
        console.log("Invalid UUID format, showing first survey")
        setShowSurvey(true)
        setCurrentSurveyOrder(1)
        setDailySurveyCompleted(false)
        return
      }

      if (!data.progress || data.progress.required_surveys_completed === 0) {
        // 今天还没有完成第一个survey，显示首次survey
        console.log("No surveys completed today, showing first survey")
        setShowSurvey(true)
        setCurrentSurveyOrder(1)
        setDailySurveyCompleted(false)
      } else {
        console.log(
          `${data.progress.required_surveys_completed} surveys completed today`
        )
        setDailySurveyCompleted(true)
        setCurrentSurveyOrder(data.progress.required_surveys_completed + 1)
      }
    } catch (error) {
      console.error("Error checking daily survey status:", error)
      // 出错时也显示首次survey以确保用户能完成
      setShowSurvey(true)
      setCurrentSurveyOrder(1)
      setDailySurveyCompleted(false)
    }
  }, [profile])

  // 开始聊天会话
  const startChatSession = useCallback(() => {
    const now = Date.now()
    setSessionStartTime(now)
    setLastActivityTime(now)
    setIsActive(true)
    setIsOnline(true)

    // 如果已完成每日首次survey，设置下一个survey时间（30秒后，测试用）
    if (dailySurveyCompleted && currentSurveyOrder <= 3) {
      setNextSurveyTime(now + 30 * 1000) // 30秒（测试用，正式版应为5分钟）
    }
  }, [dailySurveyCompleted, currentSurveyOrder])

  // 更新用户活动时间
  const updateActivity = useCallback(() => {
    const now = Date.now()
    setLastActivityTime(now)

    if (!isOnline) {
      setIsOnline(true)
      // 重新上线时，如果需要survey且时间已到，重新设置survey时间
      if (dailySurveyCompleted && currentSurveyOrder <= 3 && sessionStartTime) {
        const timeSinceStart = now - sessionStartTime
        const surveysNeeded = Math.floor(timeSinceStart / (30 * 1000)) + 1 // 30秒间隔（测试用）
        if (surveysNeeded > currentSurveyOrder - 1) {
          setNextSurveyTime(now + 30 * 1000) // 30秒（测试用）
        }
      }
    }
  }, [isOnline, dailySurveyCompleted, currentSurveyOrder, sessionStartTime])

  // 处理survey完成
  const handleSurveyCompleted = useCallback(() => {
    setShowSurvey(false)

    if (!dailySurveyCompleted) {
      // 完成了每日首次survey
      setDailySurveyCompleted(true)
      setCurrentSurveyOrder(2)
      startChatSession() // 开始计时
    } else {
      // 完成了定时survey
      setCurrentSurveyOrder(prev => prev + 1)
      const now = Date.now()
      if (currentSurveyOrder < 3) {
        setNextSurveyTime(now + 30 * 1000) // 下一个survey在30秒后（测试用）
      } else {
        setNextSurveyTime(null) // 所有必需的survey已完成
      }
    }

    // 触发进度更新事件
    window.dispatchEvent(
      new CustomEvent("surveyCompleted", {
        detail: { progress: null }
      })
    )
  }, [dailySurveyCompleted, currentSurveyOrder, startChatSession])

  // 监听聊天消息变化来检测用户活动
  useEffect(() => {
    if (chatMessages.length > 0) {
      updateActivity()

      // 如果这是用户的第一条消息且完成了每日survey，开始计时
      if (!isActive && dailySurveyCompleted) {
        startChatSession()
      }
    }
  }, [
    chatMessages,
    updateActivity,
    startChatSession,
    isActive,
    dailySurveyCompleted
  ])

  // 检查离线状态和survey时间
  useEffect(() => {
    const interval = setInterval(() => {
      const now = Date.now()
      const timeSinceActivity = now - lastActivityTime

      // 检查是否离线（10秒无活动，测试用）
      if (timeSinceActivity > 10 * 1000) {
        setIsOnline(false)
        setIsActive(false)
      }

      // 检查是否需要弹出survey
      if (
        isOnline &&
        nextSurveyTime &&
        now >= nextSurveyTime &&
        currentSurveyOrder <= 3
      ) {
        setShowSurvey(true)
        setNextSurveyTime(null)
      }
    }, 1000) // 每秒检查一次

    return () => clearInterval(interval)
  }, [lastActivityTime, nextSurveyTime, currentSurveyOrder, isOnline])

  // 初始化检查
  useEffect(() => {
    checkDailySurveyStatus()
  }, [checkDailySurveyStatus])

  // 监听survey完成事件
  useEffect(() => {
    const handleSurveyCompletedEvent = () => {
      handleSurveyCompleted()
    }

    window.addEventListener("surveyCompleted", handleSurveyCompletedEvent)

    return () => {
      window.removeEventListener("surveyCompleted", handleSurveyCompletedEvent)
    }
  }, [handleSurveyCompleted])

  return (
    <>
      {/* 活动跟踪器 */}
      <ActivityTracker onActivity={updateActivity} />

      {/* 在线状态指示器 */}
      {isActive && (
        <div className="fixed right-4 top-4 z-50">
          <div
            className={`flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium ${
              isOnline
                ? "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                : "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
            }`}
          >
            <div
              className={`size-2 rounded-full${
                isOnline ? "bg-green-500" : "bg-red-500"
              }`}
            />
            {isOnline ? "Online" : "Offline - Resume chatting to continue"}
          </div>
        </div>
      )}

      {/* Survey弹窗 */}
      {showSurvey && (
        <WelcomeDialog
          surveyOrder={currentSurveyOrder}
          isTimedSurvey={dailySurveyCompleted}
          onComplete={handleSurveyCompleted}
        />
      )}
    </>
  )
}
