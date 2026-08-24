import type {
  Attribute,
  ChildAttribute,
  Html,
  HtmlBuilder,
  TagName,
} from 'foldkit/html'
import type { MountAction } from 'foldkit/mount'

type FoldkitChild = Html | string
type RenderedProp<Message> = Attribute<Message> | ChildAttribute
type ElementInput<Message> = Readonly<{
  tag: TagName
  attributes: ReadonlyArray<RenderedProp<Message>>
  children: ReadonlyArray<FoldkitChild>
}>
type KeyedInput<Message> = ElementInput<Message> & Readonly<{ key: string }>

export const attributeImpl = <Message>(
  builder: HtmlBuilder<Message>,
  key: string,
  value: string,
): RenderedProp<Message> => builder.Attribute(key, value)

export const emptyImpl = <Message>(builder: HtmlBuilder<Message>): FoldkitChild => builder.empty

export const elementImpl = <Message>(
  builder: HtmlBuilder<Message>,
  input: ElementInput<Message>,
): FoldkitChild => builder[input.tag](input.attributes, input.children)

export const innerHtmlImpl = <Message>(
  builder: HtmlBuilder<Message>,
  value: string,
): RenderedProp<Message> => builder.InnerHTML(value)

export const keyedImpl = <Message>(
  builder: HtmlBuilder<Message>,
  input: KeyedInput<Message>,
): FoldkitChild => builder.keyed(input.tag)(input.key, input.attributes, input.children)

export const onClickImpl = <Message>(
  builder: HtmlBuilder<Message>,
  message: Message,
): RenderedProp<Message> => builder.OnClick(message)

export const onMouseEnterImpl = <Message>(
  builder: HtmlBuilder<Message>,
  message: Message,
): RenderedProp<Message> => builder.OnMouseEnter(message)

export const onMouseLeaveImpl = <Message>(
  builder: HtmlBuilder<Message>,
  message: Message,
): RenderedProp<Message> => builder.OnMouseLeave(message)

export const onMountImpl = <Message>(
  builder: HtmlBuilder<Message>,
  action: MountAction<Message>,
): RenderedProp<Message> => builder.OnMount(action)

export const rootImpl = (child: FoldkitChild): Html => {
  if (typeof child === 'string') {
    throw new Error('The root Foldkit view must be an element or empty node')
  }
  return child
}

export const textImpl = (value: string): FoldkitChild => value
