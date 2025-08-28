"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle
} from "@/components/ui/card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from "@/components/ui/dialog"
import { ScrollArea } from "@/components/ui/scroll-area"
import {
  Shield,
  Users,
  MessageSquare,
  BarChart3,
  Download,
  LogOut,
  Eye,
  Calendar,
  Activity,
  FileText
} from "lucide-react"
import { Alert, AlertDescription } from "@/components/ui/alert"

interface UserData {
  user_id: string
  email: string
  display_name: string
  username: string
  created_at: string
  has_onboarded: boolean
  statistics: {
    total_required_surveys: number
    total_extra_surveys: number
    total_messages: number
    total_chats: number
    active_days: number
  }
  daily_progress: any[]
  emoji_surveys: any[]
  chats: any[]
  messages: any[]
}

interface AdminData {
  id: string
  email: string
  name: string
}

export default function AdminDashboard() {
  const router = useRouter()
  const [admin, setAdmin] = useState<AdminData | null>(null)
  const [users, setUsers] = useState<UserData[]>([])
  const [summary, setSummary] = useState<any>({})
  const [loading, setLoading] = useState(true)
  const [exporting, setExporting] = useState(false)
  const [selectedUser, setSelectedUser] = useState<UserData | null>(null)
  const [error, setError] = useState("")

  useEffect(() => {
    checkAuth()
    loadUsersData()
  }, [])

  const checkAuth = async () => {
    try {
      const response = await fetch("/api/admin/auth", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ action: "verify" })
      })

      if (!response.ok) {
        router.push("/admin/login")
        return
      }

      const data = await response.json()
      if (data.success) {
        setAdmin(data.admin)
      } else {
        router.push("/admin/login")
      }
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/admin/login")
    }
  }

  const loadUsersData = async () => {
    try {
      setLoading(true)
      const response = await fetch("/api/admin/users")

      if (!response.ok) {
        throw new Error("Failed to load user data")
      }

      const data = await response.json()
      if (data.success) {
        setUsers(data.users)
        setSummary(data.summary)
      } else {
        setError("Failed to load user data")
      }
    } catch (error: any) {
      console.error("Load users error:", error)
      setError(error.message || "Failed to load data")
    } finally {
      setLoading(false)
    }
  }

  const handleLogout = async () => {
    try {
      await fetch("/api/admin/auth", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ action: "logout" })
      })
    } catch (error) {
      console.error("Logout error:", error)
    } finally {
      router.push("/admin/login")
    }
  }

  const handleExport = async () => {
    try {
      setExporting(true)
      const response = await fetch("/api/admin/export")

      if (!response.ok) {
        throw new Error("Export failed")
      }

      // 获取文件名
      const contentDisposition = response.headers.get("content-disposition")
      const filename = contentDisposition
        ? contentDisposition.split("filename=")[1].replace(/"/g, "")
        : "mentalshield-export.jsonl"

      // 下载文件
      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.style.display = "none"
      a.href = url
      a.download = filename
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
    } catch (error: any) {
      console.error("Export error:", error)
      setError(error.message || "Export failed")
    } finally {
      setExporting(false)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString("zh-CN")
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="size-32 animate-spin rounded-full border-b-2 border-blue-600"></div>
          <p className="mt-4 text-gray-600">加载中...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="border-b bg-white shadow-sm">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <div className="flex items-center">
              <Shield className="mr-3 size-8 text-blue-600" />
              <div>
                <h1 className="text-xl font-semibold text-gray-900">
                  MentalShield Project 管理后台
                </h1>
                <p className="text-sm text-gray-500">欢迎，{admin?.name}</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Button
                onClick={() => router.push("/zh/admin/track")}
                variant="outline"
              >
                <Activity className="mr-2 size-4" />
                用户跟踪
              </Button>
              <Button
                onClick={handleExport}
                disabled={exporting}
                className="bg-green-600 hover:bg-green-700"
              >
                <Download className="mr-2 size-4" />
                {exporting ? "导出中..." : "导出数据"}
              </Button>
              <Button onClick={handleLogout} variant="outline">
                <LogOut className="mr-2 size-4" />
                退出登录
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {error && (
          <Alert className="mb-6" variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {/* 统计卡片 */}
        <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">总用户数</CardTitle>
              <Users className="text-muted-foreground size-4" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {summary.total_users || 0}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">总调查数</CardTitle>
              <BarChart3 className="text-muted-foreground size-4" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {summary.total_surveys || 0}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">总消息数</CardTitle>
              <MessageSquare className="text-muted-foreground size-4" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {summary.total_messages || 0}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">总对话数</CardTitle>
              <FileText className="text-muted-foreground size-4" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {summary.total_chats || 0}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 用户数据表格 */}
        <Card>
          <CardHeader>
            <CardTitle>用户数据总览</CardTitle>
            <CardDescription>所有参与项目的用户详细信息和进度</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>用户</TableHead>
                    <TableHead>邮箱</TableHead>
                    <TableHead>注册时间</TableHead>
                    <TableHead>活跃天数</TableHead>
                    <TableHead>必需调查</TableHead>
                    <TableHead>额外调查</TableHead>
                    <TableHead>消息数</TableHead>
                    <TableHead>状态</TableHead>
                    <TableHead>操作</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {users.map(user => (
                    <TableRow key={user.user_id}>
                      <TableCell className="font-medium">
                        {user.display_name || user.username}
                      </TableCell>
                      <TableCell>{user.email}</TableCell>
                      <TableCell>{formatDate(user.created_at)}</TableCell>
                      <TableCell>
                        <Badge variant="secondary">
                          <Calendar className="mr-1 size-3" />
                          {user.statistics.active_days}天
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant="default">
                          {user.statistics.total_required_surveys}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">
                          {user.statistics.total_extra_surveys}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">
                          <MessageSquare className="mr-1 size-3" />
                          {user.statistics.total_messages}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={
                            user.has_onboarded ? "default" : "destructive"
                          }
                        >
                          {user.has_onboarded ? "已完成设置" : "未完成设置"}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Dialog>
                          <DialogTrigger asChild>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => setSelectedUser(user)}
                            >
                              <Eye className="mr-1 size-4" />
                              查看详情
                            </Button>
                          </DialogTrigger>
                          <DialogContent className="max-h-[80vh] max-w-4xl">
                            <DialogHeader>
                              <DialogTitle>
                                用户详情：
                                {selectedUser?.display_name ||
                                  selectedUser?.username}
                              </DialogTitle>
                              <DialogDescription>
                                {selectedUser?.email} -{" "}
                                {selectedUser &&
                                  formatDate(selectedUser.created_at)}
                              </DialogDescription>
                            </DialogHeader>

                            {selectedUser && (
                              <ScrollArea className="h-[60vh]">
                                <Tabs defaultValue="surveys" className="w-full">
                                  <TabsList className="grid w-full grid-cols-3">
                                    <TabsTrigger value="surveys">
                                      Emoji调查
                                    </TabsTrigger>
                                    <TabsTrigger value="chats">
                                      聊天记录
                                    </TabsTrigger>
                                    <TabsTrigger value="progress">
                                      每日进度
                                    </TabsTrigger>
                                  </TabsList>

                                  <TabsContent
                                    value="surveys"
                                    className="space-y-4"
                                  >
                                    <div className="grid grid-cols-1 gap-4">
                                      {selectedUser.emoji_surveys.map(
                                        (survey, index) => (
                                          <Card key={index}>
                                            <CardContent className="pt-4">
                                              <div className="flex items-start justify-between">
                                                <div>
                                                  <p className="font-medium">
                                                    {survey.question_text}
                                                  </p>
                                                  <p className="text-sm text-gray-600">
                                                    情感评分:{" "}
                                                    {survey.emotion_score}/5
                                                  </p>
                                                  <p className="text-sm text-gray-500">
                                                    {formatDate(
                                                      survey.created_at
                                                    )}
                                                  </p>
                                                </div>
                                                <Badge
                                                  variant={
                                                    survey.survey_type ===
                                                    "daily_required"
                                                      ? "default"
                                                      : "secondary"
                                                  }
                                                >
                                                  {survey.survey_type ===
                                                  "daily_required"
                                                    ? "必需"
                                                    : "额外"}
                                                </Badge>
                                              </div>
                                            </CardContent>
                                          </Card>
                                        )
                                      )}
                                    </div>
                                  </TabsContent>

                                  <TabsContent
                                    value="chats"
                                    className="space-y-4"
                                  >
                                    <div className="grid grid-cols-1 gap-4">
                                      {selectedUser.chats.map((chat, index) => (
                                        <Card key={index}>
                                          <CardContent className="pt-4">
                                            <div className="mb-2 flex items-start justify-between">
                                              <h4 className="font-medium">
                                                {chat.name}
                                              </h4>
                                              <p className="text-sm text-gray-500">
                                                {formatDate(chat.created_at)}
                                              </p>
                                            </div>
                                            <div className="max-h-40 space-y-2 overflow-y-auto">
                                              {selectedUser.messages
                                                .filter(
                                                  msg => msg.chat_id === chat.id
                                                )
                                                .slice(0, 5)
                                                .map((message, msgIndex) => (
                                                  <div
                                                    key={msgIndex}
                                                    className="text-sm"
                                                  >
                                                    <span className="font-medium">
                                                      {message.role === "user"
                                                        ? "用户"
                                                        : "助手"}
                                                      :
                                                    </span>
                                                    <span className="ml-2 text-gray-700">
                                                      {message.content.substring(
                                                        0,
                                                        100
                                                      )}
                                                      {message.content.length >
                                                      100
                                                        ? "..."
                                                        : ""}
                                                    </span>
                                                  </div>
                                                ))}
                                            </div>
                                          </CardContent>
                                        </Card>
                                      ))}
                                    </div>
                                  </TabsContent>

                                  <TabsContent
                                    value="progress"
                                    className="space-y-4"
                                  >
                                    <div className="grid grid-cols-1 gap-4">
                                      {selectedUser.daily_progress.map(
                                        (progress, index) => (
                                          <Card key={index}>
                                            <CardContent className="pt-4">
                                              <div className="flex items-center justify-between">
                                                <div>
                                                  <p className="font-medium">
                                                    {progress.session_date}
                                                  </p>
                                                  <p className="text-sm text-gray-600">
                                                    必需调查:{" "}
                                                    {
                                                      progress.required_surveys_completed
                                                    }
                                                    /3
                                                  </p>
                                                  <p className="text-sm text-gray-600">
                                                    额外调查:{" "}
                                                    {
                                                      progress.extra_surveys_completed
                                                    }
                                                  </p>
                                                </div>
                                                <Badge
                                                  variant={
                                                    progress.required_surveys_completed >=
                                                    3
                                                      ? "default"
                                                      : "destructive"
                                                  }
                                                >
                                                  {progress.required_surveys_completed >=
                                                  3
                                                    ? "完成"
                                                    : "未完成"}
                                                </Badge>
                                              </div>
                                            </CardContent>
                                          </Card>
                                        )
                                      )}
                                    </div>
                                  </TabsContent>
                                </Tabs>
                              </ScrollArea>
                            )}
                          </DialogContent>
                        </Dialog>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </main>
    </div>
  )
}
