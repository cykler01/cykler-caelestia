pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.utils
import qs.modules.launcher.services

// NOTE(fork): the sidebar AI chat. Conversations are saved to a JSON file as they are
// sent and answered, and the chat last looked at is remembered, so closing the sidebar
// or reloading the shell does not lose them. The provider, model and key come from the
// launcher's AI settings (modules/launcher/services/Ai.qml), so both features talk to
// the same service.
Singleton {
    id: root

    readonly property string storePath: `${Paths.data}/ai-chats.json`

    // { id, title, createdAt, updatedAt, messages: [{ role: "user"|"assistant", content }] }
    property var chats: []
    // The chat on show in the sidebar tab; "" is a fresh, unsaved chat
    property string activeId: ""
    // The chat waiting for a reply, if any. One request at a time, so the tab can show
    // that it is thinking and refuse to send twice
    property string pendingId: ""
    property string errorText: ""
    property bool loaded: false

    readonly property bool busy: root.pendingId !== ""
    readonly property var activeChat: root.chats.find(c => c.id === root.activeId) ?? null
    // Most recently used first, which is the order the history list shows
    readonly property var recentChats: [...root.chats].sort((a, b) => b.updatedAt - a.updatedAt)

    readonly property string systemPrompt: "You are the AI assistant built into a Linux desktop shell for computer enthusiasts. Answer usefully in plain text without markdown formatting, keeping replies clear and reasonably brief."

    function uid(): string {
        return `${Date.now().toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`;
    }

    function save(): void {
        const data = JSON.stringify({
            version: 1,
            chats: root.chats.filter(c => c.messages.length > 0),
            lastChatId: root.chats.some(c => c.id === root.activeId && c.messages.length > 0) ? root.activeId : ""
        });
        // Deferred so writing right after the file turns out not to exist yet is safe,
        // like the other services that seed a state file
        Qt.callLater(() => storage.setText(data));
    }

    // A fresh chat is nothing yet, so it is not put in the store until its first message
    function newChat(): void {
        root.activeId = "";
        root.errorText = "";
    }

    function selectChat(id: string): void {
        if (!root.chats.some(c => c.id === id))
            return;

        root.activeId = id;
        root.errorText = "";
        root.save();
    }

    function removeChat(id: string): void {
        if (!root.chats.some(c => c.id === id))
            return;

        root.chats = root.chats.filter(c => c.id !== id);
        if (root.activeId === id)
            root.activeId = root.recentChats[0]?.id ?? "";
        root.save();
    }

    function editChat(id: string, fields: var): void {
        root.chats = root.chats.map(c => c.id === id ? Object.assign({}, c, fields) : c);
        root.save();
    }

    // Sends a message in the active chat, opening a new one if there is none. The
    // conversation so far goes with it, so the assistant has its context; the reply is
    // appended to the chat it was asked in, even if another one is on show by then.
    function send(text: string): bool {
        const content = text.trim();
        if (!content || root.busy)
            return false;

        if (!Ai.configured) {
            root.errorText = Ai.provider.key ? Tr.tr("Set an API key for %1 in the Launcher settings").arg(Ai.provider.name) : Tr.tr("Set up an AI provider in the Launcher settings");
            return false;
        }

        if (!root.activeChat) {
            const id = root.uid();
            root.chats = [{
                    id,
                    title: content.split("\n")[0].slice(0, 80),
                    createdAt: Date.now(),
                    updatedAt: Date.now(),
                    messages: []
                }, ...root.chats];
            root.activeId = id;
        }

        const chat = root.activeChat;
        const messages = [...chat.messages, {
                role: "user",
                content
            }];

        root.errorText = "";
        root.pendingId = chat.id;
        root.editChat(chat.id, {
            messages,
            updatedAt: Date.now()
        });

        Ai.send(messages, root.systemPrompt, answer => root.handleAnswer(chat.id, answer), (metadata, response) => root.handleError(chat.id, metadata, response));
        return true;
    }

    function handleAnswer(id: string, answer: var): void {
        if (root.pendingId !== id)
            return;

        root.pendingId = "";

        if (answer === undefined || answer === "") {
            root.errorText = Tr.tr("The AI returned no answer");
            return;
        }

        const chat = root.chats.find(c => c.id === id);
        // The chat may have been deleted while the request was out
        if (!chat)
            return;

        root.editChat(id, {
            messages: [...chat.messages, {
                    role: "assistant",
                    content: answer
                }],
            updatedAt: Date.now()
        });
    }

    function handleError(id: string, metadata: var, response: string): void {
        if (root.pendingId !== id)
            return;

        root.pendingId = "";
        root.errorText = Ai.errorMessage(metadata, response);
    }

    // A chat from disk into one every function above can rely on: string messages with a
    // known role, timestamps and a title (taken from the first question when missing)
    function normaliseChat(chat: var): var {
        const messages = Array.isArray(chat.messages) ? chat.messages.filter(m => m && typeof m.content === "string" && m.content !== "").map(m => ({
                    role: m.role === "assistant" ? "assistant" : "user",
                    content: m.content
                })) : [];
        return {
            id: typeof chat.id === "string" && chat.id ? chat.id : root.uid(),
            title: typeof chat.title === "string" && chat.title ? chat.title : (messages.find(m => m.role === "user")?.content.split("\n")[0].slice(0, 80) ?? Tr.tr("New chat")),
            createdAt: typeof chat.createdAt === "number" ? chat.createdAt : Date.now(),
            updatedAt: typeof chat.updatedAt === "number" ? chat.updatedAt : Date.now(),
            messages
        };
    }

    function load(text: string): void {
        let chats = [];
        let lastChatId = "";

        try {
            const data = JSON.parse(text);
            if (data && typeof data === "object") {
                if (Array.isArray(data.chats))
                    chats = data.chats.map(root.normaliseChat).filter(c => c.messages.length > 0);
                if (typeof data.lastChatId === "string")
                    lastChatId = data.lastChatId;
            }
        } catch (e) {
            console.warn(lc, `Unable to parse the AI chats: ${e}`);
        }

        root.chats = chats;
        root.activeId = chats.some(c => c.id === lastChatId) ? lastChatId : "";
        root.loaded = true;
    }

    FileView {
        id: storage

        printErrors: false
        path: root.storePath
        onLoaded: root.load(text())
        onLoadFailed: err => {
            // No chats saved yet is the normal first run
            if (err !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load the AI chats: ${err}`);
            root.loaded = true;
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.aichat"
        defaultLogLevel: LoggingCategory.Warning
    }
}
