export class Comic {
  title: string = ''
  cover: string = ''
  id: string = ''
  subtitle: string = ''
  tags: string[] = []
  description: string = ''
  sourceKey: string = ''
  maxPage: number = 0
  language: string = ''
  favoriteId: string = ''
  stars: number = 0
  hasNewUpdate: boolean = false
  updateTime: string = ''
}

export class ComicDetails extends Comic {
  chapters: ComicChapters | null = null
  thumbnails: string[] = []
  recommend: Comic[] = []
  isFavorite: boolean = false
  isLiked: boolean = false
  likesCount: number = 0
  commentCount: number = 0
  uploader: string = ''
  uploadTime: string = ''
  updateTime: string = ''
  url: string = ''
  subId: string = ''
  comments: Comment[] = []
}

export class Comment {
  userName: string = ''
  avatar: string = ''
  content: string = ''
  time: string = ''
  replyCount: number = 0
  id: string = ''
  score: number = 0
  isLiked: boolean = false
  voteStatus: number = 0
}

export class ArchiveInfo {
  title: string = ''
  description: string = ''
  id: string = ''
}

export class ComicChapters {
  private _chapters: Record<string, string> = {}
  private _groupedChapters: Record<string, Record<string, string>> = {}
  private _isGrouped: boolean = false

  get isGrouped(): boolean {
    return this._isGrouped
  }

  get groups(): string[] {
    return Object.keys(this._groupedChapters)
  }

  get allChapters(): Record<string, string> {
    return this._chapters
  }

  get length(): number {
    return Object.keys(this._chapters).length
  }

  get ids(): string[] {
    return Object.keys(this._chapters)
  }

  get titles(): string[] {
    return Object.values(this._chapters)
  }

  get groupCount(): number {
    return Object.keys(this._groupedChapters).length
  }

  static fromFlatChapters(chapters: Record<string, string>): ComicChapters {
    let c: ComicChapters = new ComicChapters()
    c._chapters = chapters
    c._isGrouped = false
    return c
  }

  static fromGroupedChapters(groups: Record<string, Record<string, string>>): ComicChapters {
    let c: ComicChapters = new ComicChapters()
    c._groupedChapters = groups
    c._isGrouped = true
    let keys: string[] = Object.keys(groups)
    for (let i: number = 0; i < keys.length; i++) {
      let group: Record<string, string> = groups[keys[i]]
      let ids: string[] = Object.keys(group)
      for (let j: number = 0; j < ids.length; j++) {
        c._chapters[ids[j]] = group[ids[j]]
      }
    }
    return c
  }

  getChapterTitle(id: string): string {
    if (this._chapters[id] !== undefined) {
      return this._chapters[id]
    }
    return ''
  }

  getGroupChapters(groupName: string): Record<string, string> {
    if (this._groupedChapters[groupName] !== undefined) {
      return this._groupedChapters[groupName]
    }
    return {}
  }
}

export class PageJumpTarget {
  sourceKey: string = ''
  page: string = ''
  attributes: Record<string, string> = {}
}

export class TextWithCount {
  text: string = ''
  count: number = 0
}
