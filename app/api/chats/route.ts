import { createRouteHandlerClient } from "@supabase/auth-helpers-nextjs"
import { cookies } from "next/headers"
import { NextResponse } from "next/server"

export async function POST(request: Request) {
  try {
    const supabase = createRouteHandlerClient({ cookies })

    // Get current user
    const {
      data: { user },
      error: userError
    } = await supabase.auth.getUser()
    if (userError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    // Get request body
    const body = await request.json()
    const { characterId, characterName, systemPrompt } = body

    // Get or create user's workspace
    const { data: workspace, error: workspaceError } = await supabase
      .from("workspaces")
      .select("*")
      .eq("user_id", user.id)
      .single()

    if (workspaceError && workspaceError.code !== "PGRST116") {
      console.error("Error fetching workspace:", workspaceError)
      return NextResponse.json(
        { error: "Failed to fetch workspace" },
        { status: 500 }
      )
    }

    let workspaceId = workspace?.id

    if (!workspaceId) {
      // Create a new workspace if it doesn't exist
      const { data: newWorkspace, error: createWorkspaceError } = await supabase
        .from("workspaces")
        .insert([
          {
            user_id: user.id,
            name: "My Workspace",
            description: "Default workspace",
            default_context_length: 4096,
            default_model: "gpt-3.5-turbo",
            default_prompt: "You are a helpful AI assistant.",
            default_temperature: 0.7,
            embeddings_provider: "openai",
            include_profile_context: true,
            include_workspace_instructions: true,
            instructions: "Be helpful and informative.",
            is_home: true
          }
        ])
        .select()
        .single()

      if (createWorkspaceError) {
        console.error("Error creating workspace:", createWorkspaceError)
        return NextResponse.json(
          { error: "Failed to create workspace" },
          { status: 500 }
        )
      }

      workspaceId = newWorkspace.id
    }

    // Create new chat
    const { data: chat, error: chatError } = await supabase
      .from("chats")
      .insert([
        {
          user_id: user.id,
          workspace_id: workspaceId,
          name: `${characterName}`,
          model: "gpt-3.5-turbo",
          prompt:
            systemPrompt ||
            `Hi there, I am ${characterName}. Start to talk with me!`,
          temperature: 0.7,
          context_length: 4096,
          embeddings_provider: "openai",
          include_profile_context: true,
          include_workspace_instructions: true
        }
      ])
      .select()
      .single()

    if (chatError) {
      console.error("Error creating chat:", chatError)
      return NextResponse.json(
        { error: "Failed to create chat" },
        { status: 500 }
      )
    }

    return NextResponse.json(chat)
  } catch (error) {
    console.error("Error in POST /api/chats:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
