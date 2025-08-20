#Requires AutoHotkey v2.0
#Include "%A_LineFile%/../../../ApiClient.ahk"

class GitHub extends ApiClient {
    __New() {
        ; specify base url
        super.__New("https://api.github.com")
    }

    static Issue(Owner, Repo, Number) => {
        Verb: "GET",
        Path: Format("/repos/{}/{}/issues/{}", Owner, Repo, Number),
        Headers: {
            Accept: "application/vnd.github+json"
        }
    }

    static SearchIssues(Owner, Repo, Query) => {
        Verb: "GET",
        Path: Format("/repos/{}/{}/issues", Owner, Repo),
        Query: Query
    }
}

GH := GitHub()

MsgBox("Searching for issue 42 on the octocat/Hello-World repo...")
MsgBox(JSON.Dump(
    GH.Issue("octocat", "Hello-World", 42)
))


MsgBox("Searching for open issues in the octocat/Linguist repo...")
MsgBox(JSON.Dump(
    GH.SearchIssues("octocat", "Linguist", {
        state: "open",
        created: "desc"
    })
))