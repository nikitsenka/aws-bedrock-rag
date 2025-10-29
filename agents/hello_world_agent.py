from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langchain_aws import ChatBedrockConverse
from typing import Annotated, TypedDict
from bedrock_agentcore import BedrockAgentCoreApp

app = BedrockAgentCoreApp()


class State(TypedDict):
    messages: Annotated[list, add_messages]


def chatbot(state: State):
    llm = ChatBedrockConverse(
        model="us.anthropic.claude-sonnet-4-5-20250929-v1:0",
        region_name="us-east-1"
    )
    return {"messages": [llm.invoke(state["messages"])]}


graph_builder = StateGraph(State)
graph_builder.add_node("chatbot", chatbot)
graph_builder.add_edge(START, "chatbot")
graph_builder.add_edge("chatbot", END)
graph = graph_builder.compile()


@app.entrypoint
def invoke(payload):
    user_message = payload.get("prompt", "Hello! Say hello world!")

    result = graph.invoke({"messages": [("user", user_message)]})

    response_message = result["messages"][-1].content

    return {"result": response_message}


if __name__ == "__main__":
    app.run()
