import { bind } from "astal"
import Hyprland from "gi://AstalHyprland"

export default function Workspaces() {
    const hypr = Hyprland.get_default()

    return <box className="Workspaces">
        {bind(hypr, "workspaces").as(wss => wss
            .sort((a, b) => a.id - b.id)
            .map(ws => (
                <button
                    className={bind(hypr, "focusedWorkspace").as(fws => 
                        fws === ws ? "focused" : ""
                    )}
                    onClicked={() => ws.focus()}>
                    <label label={String(ws.id)} />
                </button>
            ))
        )}
    </box>
}
