"use client"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { useParams } from "next/navigation"

export default function CharactersPage() {
  const router = useRouter()
  const params = useParams()
  const locale = params ? (params.locale as string) : ""
  const [searchTerm, setSearchTerm] = useState("")
  const [currentPage, setCurrentPage] = useState(1)
  const charactersPerPage = 12
  const [characters, setCharacters] = useState<
    {
      rank: number
      name: string
      description: string
      background: string
      systemPrompt: string // 添加systemPrompt属性
    }[]
  >([])
  const [characterPrompts, setCharacterPrompts] = useState({})

  useEffect(() => {
    // Fetch character data from API
    fetch("/api/prompts")
      .then(response => response.json())
      .then(
        (data: Array<{ character_name: string; system_prompt: string }>) => {
          console.log("Loaded character data:", data) // Debug log
          const loadedCharacters = data.map((item, index) => ({
            rank: index + 1,
            name: item.character_name,
            description: item.system_prompt.split("\n")[0], // Use first line of prompt as description
            background: "From JSONL",
            systemPrompt: item.system_prompt // 添加系统提示
          }))
          setCharacters(loadedCharacters)
        }
      )
      .catch(error => console.error("Error fetching character data:", error))
  }, [])

  // 过滤角色
  const filteredCharacters = characters.filter(
    character =>
      character.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      character.description.toLowerCase().includes(searchTerm.toLowerCase())
  )

  // 计算总页数
  const totalPages = Math.ceil(filteredCharacters.length / charactersPerPage)

  // 获取当前页的角色
  const currentCharacters = filteredCharacters.slice(
    (currentPage - 1) * charactersPerPage,
    currentPage * charactersPerPage
  )

  const handleChoose = async (character: (typeof characters)[0]) => {
    try {
      // Create new chat session
      const response = await fetch("/api/chats", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          characterId: character.rank,
          characterName: character.name,
          systemPrompt:
            (characterPrompts as any)[character.name] ||
            `You are ${character.name}, a helpful AI assistant.`
        })
      })

      if (!response.ok) {
        throw new Error("Failed to create chat")
      }

      const newChat = await response.json()

      // Navigate to workspace chat page
      router.push(
        `/${locale}/${newChat.workspace_id}/chat/${newChat.id}?characterName=${character.name}`
      )
    } catch (error) {
      console.error("Failed to create chat:", error)
      // Add error notification here
    }
  }

  useEffect(() => {
    // Fetch character prompts from API
    fetch("/api/prompts")
      .then(response => response.json())
      .then(
        (data: Array<{ character_name: string; system_prompt: string }>) => {
          const prompts: { [key: string]: string } = {}
          data.forEach(
            (item: { character_name: string; system_prompt: string }) => {
              prompts[item.character_name] = item.system_prompt
            }
          )
          setCharacterPrompts(prompts)
        }
      )
      .catch(error => console.error("Error fetching character prompts:", error))
  }, [])

  return (
    <div className="container mx-auto p-6">
      <h1 className="mb-8 text-center text-3xl font-bold">Character Choose</h1>

      {/* 搜索框 */}
      <div className="mb-6">
        <Input
          type="text"
          placeholder="Search characters..."
          value={searchTerm}
          onChange={e => setSearchTerm(e.target.value)}
          className="mx-auto max-w-md"
        />
      </div>

      {/* 角色网格 */}
      <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        {currentCharacters.map(character => (
          <div
            key={character.rank}
            className="rounded-lg border p-6 shadow-sm transition-shadow hover:shadow-md"
          >
            <div className="mb-2 flex items-center justify-between">
              <h2 className="text-xl font-semibold">{character.name}</h2>
              <span className="text-muted-foreground text-sm">
                #{character.rank}
              </span>
            </div>
            <p className="text-muted-foreground mb-2 text-sm">
              {character.background}
            </p>
            <p className="mb-4 text-sm">{character.description}</p>
            <Button className="w-full" onClick={() => handleChoose(character)}>
              Choose
            </Button>
          </div>
        ))}
      </div>

      {/* 分页控制 */}
      <div className="mt-8 flex justify-center gap-2">
        <Button
          variant="outline"
          onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
          disabled={currentPage === 1}
        >
          Previous
        </Button>
        <span className="flex items-center px-4">
          Page {currentPage} of {totalPages}
        </span>
        <Button
          variant="outline"
          onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
          disabled={currentPage === totalPages}
        >
          Next
        </Button>
      </div>
    </div>
  )
}
