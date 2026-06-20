import { RouterUtil } from '../navigation/RouterUtil';

interface RichSpan {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  link: string;
}

@Component
export struct RichCommentContent {
  @Prop text: string = ''
  @Prop useLightText: boolean = false
  @State spans: RichSpan[] = []

  aboutToAppear(): void {
    this.spans = RichCommentContent.parse(this.text);
  }

  aboutToUpdate(): void {
    this.spans = RichCommentContent.parse(this.text);
  }

  static stripTags(input: string): string {
    return input.replace(/<[^>]+>/g, '');
  }

  static parse(input: string): RichSpan[] {
    if (input.length === 0) {
      return [];
    }
    if (!input.includes('<') && !input.includes('http')) {
      return [{ text: input, bold: false, italic: false, underline: false, link: '' }];
    }
    let result: RichSpan[] = [];
    let plain = input.replace(/<br\s*\/?>/gi, '\n');
    let regex = /<a\s+href=["']([^"']+)["'][^>]*>(.*?)<\/a>/gi;
    let lastIndex = 0;
    let match: RegExpExecArray | null = regex.exec(plain);
    while (match !== null) {
      if (match.index > lastIndex) {
        RichCommentContent.pushStyled(plain.substring(lastIndex, match.index), result);
      }
      result.push({
        text: RichCommentContent.stripTags(match[2]),
        bold: false,
        italic: false,
        underline: true,
        link: match[1]
      });
      lastIndex = match.index + match[0].length;
      match = regex.exec(plain);
    }
    if (lastIndex < plain.length) {
      RichCommentContent.pushStyled(plain.substring(lastIndex), result);
    }
    if (result.length === 0) {
      RichCommentContent.pushStyled(plain, result);
    }
    return result;
  }

  private static pushStyled(chunk: string, result: RichSpan[]): void {
    let parts: string[] = chunk.split(/(<\/?(?:b|i|u|strong|em)>)/gi);
    let bold = false;
    let italic = false;
    let underline = false;
    for (let i: number = 0; i < parts.length; i++) {
      let part = parts[i];
      if (part.length === 0) {
        continue;
      }
      let lower = part.toLowerCase();
      if (lower === '<b>' || lower === '<strong>') {
        bold = true;
        continue;
      }
      if (lower === '</b>' || lower === '</strong>') {
        bold = false;
        continue;
      }
      if (lower === '<i>' || lower === '<em>') {
        italic = true;
        continue;
      }
      if (lower === '</i>' || lower === '</em>') {
        italic = false;
        continue;
      }
      if (lower === '<u>') {
        underline = true;
        continue;
      }
      if (lower === '</u>') {
        underline = false;
        continue;
      }
      let cleaned = part.replace(/<[^>]+>/g, '');
      if (cleaned.length === 0) {
        continue;
      }
      RichCommentContent.splitUrls(cleaned, bold, italic, underline, result);
    }
  }

  private static splitUrls(
    text: string,
    bold: boolean,
    italic: boolean,
    underline: boolean,
    result: RichSpan[]
  ): void {
    let urlRegex = /(https?:\/\/[^\s<]+)/g;
    let last = 0;
    let m: RegExpExecArray | null = urlRegex.exec(text);
    while (m !== null) {
      if (m.index > last) {
        result.push({ text: text.substring(last, m.index), bold, italic, underline, link: '' });
      }
      result.push({ text: m[1], bold, italic, underline: true, link: m[1] });
      last = m.index + m[0].length;
      m = urlRegex.exec(text);
    }
    if (last < text.length) {
      result.push({ text: text.substring(last), bold, italic, underline, link: '' });
    }
  }

  private openLink(link: string): void {
    if (link.length === 0) {
      return;
    }
    RouterUtil.openWebView(link);
  }

  build() {
    Text() {
      ForEach(this.spans, (span: RichSpan, index: number) => {
        Span(span.text)
          .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
          .decoration({
            type: span.underline || span.link.length > 0 ? TextDecorationType.Underline :
              TextDecorationType.None
          })
          .fontColor(span.link.length > 0 ? $r('app.color.color_emphasize') :
            (this.useLightText ? Color.White : $r('app.color.text_primary')))
          .onClick(() => {
            if (span.link.length > 0) {
              this.openLink(span.link);
            }
          })
      }, (span: RichSpan, index: number) => index.toString() + span.text.substring(0, 8))
    }
    .fontSize(13)
    .width('100%')
  }
}
