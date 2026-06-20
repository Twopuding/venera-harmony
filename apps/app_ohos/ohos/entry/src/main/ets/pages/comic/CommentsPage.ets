import router from '@ohos.router';
import { DataService, CommentInfo, CommentsLoadResult } from '../../service/DataService';
import { LoadingIndicator } from '../../components/LoadingIndicator';
import { NetworkError } from '../../components/NetworkError';
import { ImmersivePageScaffold } from '../../components/ImmersivePageScaffold';
import { RouterUtil } from '../../navigation/RouterUtil';
import { RichCommentContent } from '../../components/RichCommentContent';
import { TranslationUtil } from '../../utils/TranslationUtil';

@Entry
@Component
struct CommentsPage {
  @State comicId: string = ''
  @State sourceKey: string = ''
  @State comments: CommentInfo[] = []
  @State isLoading: boolean = true
  @State isLoadingMore: boolean = false
  @State errorMessage: string = ''
  @State currentPage: number = 1
  @State hasMore: boolean = false
  @State newComment: string = ''
  @State isPosting: boolean = false
  @State replyTo: string = ''
  @State replyUserName: string = ''
  @State parentComment: CommentInfo | null = null
  private context = getContext(this)

  private tr(key: string): string {
    return TranslationUtil.tl(key, this.context);
  }

  aboutToAppear(): void {
    TranslationUtil.ensureLoaded(this.context);
    let params = router.getParams() as Record<string, string>;
    this.comicId = params['comicId'] ?? '';
    this.sourceKey = params['sourceKey'] ?? '';
    this.replyTo = params['replyTo'] ?? '';
    this.replyUserName = params['replyUserName'] ?? '';
    this.loadPage(1);
  }

  private async loadPage(page: number): Promise<void> {
    if (page === 1) {
      this.isLoading = true;
      this.errorMessage = '';
    } else {
      this.isLoadingMore = true;
    }
    try {
      let replyArg: string | undefined = this.replyTo.length > 0 ? this.replyTo : undefined;
      let result: CommentsLoadResult = await DataService.getInstance().loadComments(
        this.sourceKey, this.comicId, page, undefined, replyArg
      );
      if (result.error !== undefined) {
        this.errorMessage = result.error;
        return;
      }
      if (page === 1) {
        this.comments = result.comments;
      } else {
        this.comments = this.comments.concat(result.comments);
      }
      this.currentPage = page;
      this.hasMore = result.hasMore;
    } catch (e) {
      this.errorMessage = 'Failed to load comments';
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  private async postComment(): Promise<void> {
    let content: string = this.newComment.trim();
    if (content.length === 0 || this.isPosting) {
      return;
    }
    this.isPosting = true;
    let replyArg: string | undefined = this.replyTo.length > 0 ? this.replyTo : undefined;
    let ok: boolean = await DataService.getInstance().postComment(
      this.sourceKey, this.comicId, content, undefined, replyArg
    );
    this.isPosting = false;
    if (ok) {
      this.newComment = '';
      await this.loadPage(1);
    }
  }

  private openReplies(comment: CommentInfo): void {
    RouterUtil.openComments(this.comicId, this.sourceKey, comment.id, comment.userName);
  }

  private async likeComment(comment: CommentInfo): Promise<void> {
    await DataService.getInstance().likeComment(
      this.sourceKey, this.comicId, '', comment.id, true
    );
    await this.loadPage(1);
  }

  private async voteComment(comment: CommentInfo, isUp: boolean): Promise<void> {
    await DataService.getInstance().voteComment(
      this.sourceKey, this.comicId, '', comment.id, isUp, false
    );
    await this.loadPage(1);
  }

  private clearReply(): void {
    this.replyTo = '';
    this.replyUserName = '';
    this.parentComment = null;
    this.loadPage(1);
  }

  private handleBack(): void {
    if (this.replyTo.length > 0) {
      this.clearReply();
    } else {
      RouterUtil.back();
    }
  }

  @Builder
  commentItem(comment: CommentInfo) {
    Column() {
      Row() {
        Text(comment.userName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        if (comment.time.length > 0) {
          Text(comment.time)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')

      RichCommentContent({ text: comment.content })
        .width('100%')
        .margin({ top: 6 })

      Row() {
        Text(this.tr('Like'))
          .fontSize(12)
          .fontColor($r('app.color.color_emphasize'))
          .onClick(() => this.likeComment(comment))
        Text('Up')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .onClick(() => this.voteComment(comment, true))
        Text('Down')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 12 })
          .onClick(() => this.voteComment(comment, false))
        if (comment.replyCount > 0) {
          Text(`${comment.replyCount} replies`)
            .fontSize(11)
            .fontColor($r('app.color.color_emphasize'))
            .margin({ left: 12 })
            .onClick(() => this.openReplies(comment))
        } else {
          Text('Reply')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 12 })
            .onClick(() => {
              this.replyTo = comment.id;
              this.replyUserName = comment.userName;
            })
        }
      }
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  pageContent() {
    Column() {
      if (this.replyTo.length > 0 && this.replyUserName.length > 0) {
        Text(`Reply thread`)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      if (this.isLoading) {
        LoadingIndicator()
      } else if (this.errorMessage.length > 0) {
        NetworkError({
          message: this.errorMessage,
          onRetry: () => this.loadPage(1)
        })
      } else if (this.comments.length === 0) {
        Text('No comments')
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      } else {
        List() {
          ForEach(this.comments, (comment: CommentInfo) => {
            ListItem() {
              this.commentItem(comment)
            }
          }, (comment: CommentInfo) => comment.id)
        }
        .layoutWeight(1)
        .width('100%')

        if (this.hasMore) {
          Button(this.isLoadingMore ? 'Loading...' : 'Load more')
            .width('80%')
            .margin({ top: 8, bottom: 16 })
            .enabled(!this.isLoadingMore)
            .onClick(() => this.loadPage(this.currentPage + 1))
        }
      }

      Row() {
        TextInput({
          placeholder: this.replyTo.length > 0 ? `Reply to ${this.replyUserName}...` : 'Write a comment...',
          text: this.newComment
        })
          .layoutWeight(1)
          .onChange((v: string) => {
            this.newComment = v;
          })
        Button(this.isPosting ? '...' : 'Post')
          .margin({ left: 8 })
          .enabled(!this.isPosting)
          .onClick(() => this.postComment())
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.card_background'))
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      ImmersivePageScaffold({
        title: this.replyTo.length > 0 ? this.tr('Replies') : this.tr('Comments'),
        showBack: true,
        scrollable: false,
        onBack: () => this.handleBack(),
        content: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
