require 'digest/md5'
module StandardTags

  include Radiant::Taggable
  include LocalTime

  class TagError < StandardError; end

  desc %{
    Causes the tags referring to a page's attributes to refer to the current page.

    *Usage:*
    
    <pre><code><r:page>...</r:page></code></pre>
  }
  tag 'page' do |tag|
    tag.locals.page = tag.globals.page
    tag.expand
  end

  [:breadcrumb, :slug, :title].each do |method|
    desc %{
      Renders the @#{method}@ attribute of the current page.
    }
    tag method.to_s do |tag|
      tag.locals.page.send(method)
    end
  end

  desc %{
    Renders the @url@ attribute of the current page.
  }
  tag 'url' do |tag|
    relative_url_for(tag.locals.page.url, tag.globals.page.request)
  end

  desc %{
    Gives access to a page's children.

    *Usage:*
    
    <pre><code><r:children>...</r:children></code></pre>
  }
  tag 'children' do |tag|
    tag.locals.children = tag.locals.page.children
    tag.expand
  end

  desc %{
    Renders the total number of children.
  }
  tag 'children:count' do |tag|
    tag.locals.children.count
  end

  desc %{
    Returns the first child. Inside this tag all page attribute tags are mapped to
    the first child. Takes the same ordering options as @<r:children:each>@.

    *Usage:*
    
    <pre><code><r:children:first>...</r:children:first></code></pre>
  }
  tag 'children:first' do |tag|
    options = children_find_options(tag)
    children = tag.locals.children.find(:all, options)
    if first = children.first
      tag.locals.page = first
      tag.expand
    end
  end

  desc %{
    Returns the last child. Inside this tag all page attribute tags are mapped to
    the last child. Takes the same ordering options as @<r:children:each>@.

    *Usage:*
    
    <pre><code><r:children:last>...</r:children:last></code></pre>
  }
  tag 'children:last' do |tag|
    options = children_find_options(tag)
    children = tag.locals.children.find(:all, options)
    if last = children.last
      tag.locals.page = last
      tag.expand
    end
  end

  desc %{
    Cycles through each of the children. Inside this tag all page attribute tags
    are mapped to the current child page.

    *Usage:*
    
    <pre><code><r:children:each [offset="number"] [limit="number"] [by="attribute"] [order="asc|desc"]
     [status="draft|reviewed|published|hidden|all"]>
     ...
    </r:children:each>
    </code></pre>
  }
  tag 'children:each' do |tag|
    options = children_find_options(tag)
    result = []
    children = tag.locals.children
    tag.locals.previous_headers = {}
    children.find(:all, options).each do |item|
      tag.locals.child = item
      tag.locals.page = item
      result << tag.expand
    end
    result
  end

  desc %{
    Page attribute tags inside of this tag refer to the current child. This is occasionally
    useful if you are inside of another tag (like &lt;r:find&gt;) and need to refer back to the
    current child.

    *Usage:*
    
    <pre><code><r:children:each>
      <r:child>...</r:child>
    </r:children:each>
    </code></pre>
  }
  tag 'children:each:child' do |tag|
    tag.locals.page = tag.locals.child
    tag.expand
  end

  desc %{
    Renders the tag contents only if the contents do not match the previous header. This
    is extremely useful for rendering date headers for a list of child pages.

    If you would like to use several header blocks you may use the @name@ attribute to
    name the header. When a header is named it will not restart until another header of
    the same name is different.

    Using the @restart@ attribute you can cause other named headers to restart when the
    present header changes. Simply specify the names of the other headers in a semicolon
    separated list.

    *Usage:*
    
    <pre><code><r:children:each>
      <r:header [name="header_name"] [restart="name1[;name2;...]"]>
        ...
      </r:header>
    </r:children:each>
    </code></pre>
  }
  tag 'children:each:header' do |tag|
    previous_headers = tag.locals.previous_headers
    name = tag.attr['name'] || :unnamed
    restart = (tag.attr['restart'] || '').split(';')
    header = tag.expand
    unless header == previous_headers[name]
      previous_headers[name] = header
      unless restart.empty?
        restart.each do |n|
          previous_headers[n] = nil
        end
      end
      header
    end
  end

  desc %{
    Page attribute tags inside this tag refer to the parent of the current page.

    *Usage:*
    
    <pre><code><r:parent>...</r:parent></code></pre>
  }
  tag "parent" do |tag|
    parent = tag.locals.page.parent
    tag.locals.page = parent
    tag.expand if parent
  end

  desc %{
    Renders the contained elements only if the current contextual page has a parent, i.e.
    is not the root page.

    *Usage:*
    
    <pre><code><r:if_parent>...</r:if_parent></code></pre>
  }
  tag "if_parent" do |tag|
    parent = tag.locals.page.parent
    tag.expand if parent
  end

  desc %{
    Renders the contained elements only if the current contextual page has no parent, i.e.
    is the root page.

    *Usage:*
    
    <pre><code><r:unless_parent>...</r:unless_parent></code></pre>
  }
  tag "unless_parent" do |tag|
    parent = tag.locals.page.parent
    tag.expand unless parent
  end

  desc %{
    Renders the contained elements only if the current contextual page has one or
    more child pages.  The @status@ attribute limits the status of found child pages
    to the given status, the default is @"published"@. @status="all"@ includes all
    non-virtual pages regardless of status.

    *Usage:*
    
    <pre><code><r:if_children [status="published"]>...</r:if_children></code></pre>
  }
  tag "if_children" do |tag|
    children = tag.locals.page.children.count(:conditions => children_find_options(tag)[:conditions])
    tag.expand if children > 0
  end

  desc %{
    Renders the contained elements only if the current contextual page has no children.
    The @status@ attribute limits the status of found child pages to the given status,
    the default is @"published"@. @status="all"@ includes all non-virtual pages
    regardless of status.

    *Usage:*
    
    <pre><code><r:unless_children [status="published"]>...</r:unless_children></code></pre>
  }
  tag "unless_children" do |tag|
    children = tag.locals.page.children.count(:conditions => children_find_options(tag)[:conditions])
    tag.expand unless children > 0
  end

  desc %{
    Renders one of the passed values based on a global cycle counter.  Use the @reset@
    attribute to reset the cycle to the beginning.  Use the @name@ attribute to track
    multiple cycles; the default is @cycle@.

    *Usage:*
    
    <pre><code><r:cycle values="first, second, third" [reset="true|false"] [name="cycle"] /></code></pre>
  }
  tag 'cycle' do |tag|
    raise TagError, "`cycle' tag must contain a `values' attribute." unless tag.attr['values']
    cycle = (tag.globals.cycle ||= {})
    values = tag.attr['values'].split(",").collect(&:strip)
    cycle_name = tag.attr['name'] || 'cycle'
    current_index = (cycle[cycle_name] ||=  0)
    current_index = 0 if tag.attr['reset'] == 'true'
    cycle[cycle_name] = (current_index + 1) % values.size
    values[current_index]
  end

  desc %{
    Renders the main content of a page. Use the @part@ attribute to select a specific
    page part. By default the @part@ attribute is set to body. Use the @inherit@
    attribute to specify that if a page does not have a content part by that name that
    the tag should render the parent's content part. By default @inherit@ is set to
    @false@. Use the @contextual@ attribute to force a part inherited from a parent
    part to be evaluated in the context of the child page. By default 'contextual'
    is set to true.

    *Usage:*
    
    <pre><code><r:content [part="part_name"] [inherit="true|false"] [contextual="true|false"] /></code></pre>
  }
  tag 'content' do |tag|
    page = tag.locals.page
    part_name = tag_part_name(tag)
    boolean_attr = proc do |attribute_name, default|
      attribute = (tag.attr[attribute_name] || default).to_s
      raise TagError.new(%{`#{attribute_name}' attribute of `content' tag must be set to either "true" or "false"}) unless attribute =~ /true|false/i
      (attribute.downcase == 'true') ? true : false
    end
    inherit = boolean_attr['inherit', false]
    part_page = page
    if inherit
      while (part_page.part(part_name).nil? and (not part_page.parent.nil?)) do
        part_page = part_page.parent
      end
    end
    contextual = boolean_attr['contextual', true]
    part = part_page.part(part_name)
    tag.locals.page = part_page unless contextual
    tag.globals.page.render_snippet(part) unless part.nil?
  end

  desc %{
    Renders the containing elements if all of the listed parts exist on a page.
    By default the @part@ attribute is set to @body@, but you may list more than one
    part by separating them with a comma. Setting the optional @inherit@ to true will
    search ancestors independently for each part. By default @inherit@ is set to @false@.

    When listing more than one part, you may optionally set the @find@ attribute to @any@
    so that it will render the containing elements if any of the listed parts are found.
    By default the @find@ attribute is set to @all@.

    *Usage:*
    
    <pre><code><r:if_content [part="part_name, other_part"] [inherit="true"] [find="any"]>...</r:if_content></code></pre>
  }
  tag 'if_content' do |tag|
    page = tag.locals.page
    part_name = tag_part_name(tag)
    parts_arr = part_name.split(',')
    inherit = boolean_attr_or_error(tag, 'inherit', 'false')
    find = attr_or_error(tag, :attribute_name => 'find', :default => 'all', :values => 'any, all')
    expandable = true
    one_found = false
    part_page = page
    parts_arr.each do |name|
      name.strip!
      if inherit
        while (part_page.part(name).nil? and (not part_page.parent.nil?)) do
          part_page = part_page.parent
        end
      end
      expandable = false if part_page.part(name).nil?
      one_found ||= true if !part_page.part(name).nil?
    end
    expandable = true if (find == 'any' and one_found)
    tag.expand if expandable
  end

  desc %{
    The opposite of the @if_content@ tag. It renders the contained elements if all of the
    specified parts do not exist. Setting the optional @inherit@ to true will search
    ancestors independently for each part. By default @inherit@ is set to @false@.

    When listing more than one part, you may optionally set the @find@ attribute to @any@
    so that it will not render the containing elements if any of the listed parts are found.
    By default the @find@ attribute is set to @all@.

    *Usage:*
    
    <pre><code><r:unless_content [part="part_name, other_part"] [inherit="false"] [find="any"]>...</r:unless_content></code></pre>
  }
  tag 'unless_content' do |tag|
    page = tag.locals.page
    part_name = tag_part_name(tag)
    parts_arr = part_name.split(',')
    inherit = boolean_attr_or_error(tag, 'inherit', false)
    find = attr_or_error(tag, :attribute_name => 'find', :default => 'all', :values => 'any, all')
    expandable, all_found = true, true
    part_page = page
    parts_arr.each do |name|
      name.strip!
      if inherit
        while (part_page.part(name).nil? and (not part_page.parent.nil?)) do
          part_page = part_page.parent
        end
      end
      expandable = false if !part_page.part(name).nil?
      all_found = false if part_page.part(name).nil?
    end
    if all_found == false and find == 'all'
      expandable = true
    end
    tag.expand if expandable
  end

  desc %{
    Renders the containing elements only if the page's url matches the regular expression
    given in the @matches@ attribute. If the @ignore_case@ attribute is set to false, the
    match is case sensitive. By default, @ignore_case@ is set to true.

    *Usage:*
    
    <pre><code><r:if_url matches="regexp" [ignore_case="true|false"]>...</r:if_url></code></pre>
  }
  tag 'if_url' do |tag|
    raise TagError.new("`if_url' tag must contain a `matches' attribute.") unless tag.attr.has_key?('matches')
    regexp = build_regexp_for(tag, 'matches')
    unless tag.locals.page.url.match(regexp).nil?
       tag.expand
    end
  end

  desc %{
    The opposite of the @if_url@ tag.

    *Usage:*
    
    <pre><code><r:unless_url matches="regexp" [ignore_case="true|false"]>...</r:unless_url></code></pre>
  }
  tag 'unless_url' do |tag|
    raise TagError.new("`unless_url' tag must contain a `matches' attribute.") unless tag.attr.has_key?('matches')
    regexp = build_regexp_for(tag, 'matches')
    if tag.locals.page.url.match(regexp).nil?
        tag.expand
    end
  end

  desc %{
    Renders the contained elements if the current contextual page is either the actual page or one of its parents.

    This is typically used inside another tag (like &lt;r:children:each&gt;) to add conditional mark-up if the child element is or descends from the current page.

    *Usage:*
    
    <pre><code><r:if_ancestor_or_self>...</r:if_ancestor_or_self></code></pre>
  }
  tag "if_ancestor_or_self" do |tag|
    tag.expand if (tag.globals.page.ancestors + [tag.globals.page]).include?(tag.locals.page)
  end

  desc %{
    Renders the contained elements unless the current contextual page is either the actual page or one of its parents.

    This is typically used inside another tag (like &lt;r:children:each&gt;) to add conditional mark-up unless the child element is or descends from the current page.

    *Usage:*
    
    <pre><code><r:unless_ancestor_or_self>...</r:unless_ancestor_or_self></code></pre>
  }
  tag "unless_ancestor_or_self" do |tag|
    tag.expand unless (tag.globals.page.ancestors + [tag.globals.page]).include?(tag.locals.page)
  end

  desc %{
    Renders the contained elements if the current contextual page is also the actual page.

    This is typically used inside another tag (like &lt;r:children:each&gt;) to add conditional mark-up if the child element is the current page.

    *Usage:*
    
    <pre><code><r:if_self>...</r:if_self></code></pre>
  }
  tag "if_self" do |tag|
    tag.expand if tag.locals.page == tag.globals.page
  end

  desc %{
    Renders the contained elements unless the current contextual page is also the actual page.

    This is typically used inside another tag (like &lt;r:children:each&gt;) to add conditional mark-up unless the child element is the current page.

    *Usage:*

    <pre><code><r:unless_self>...</r:unless_self></code></pre>
  }
  tag "unless_self" do |tag|
    tag.expand unless tag.locals.page == tag.globals.page
  end

  desc %{
    Renders the name of the author of the current page when used as a 
    single tag, but will set the scope to the current author when used
    as a double tag.
    
    *Usage:*
    <pre><code><r:author /></code></pre>
    <pre><code><r:author>text</r:author></code></pre>
  }
  tag 'author' do |tag|
    if tag.locals.author
      tag.double? ? tag.expand : tag.locals.author.name
    else
      page = tag.locals.page
      if tag.locals.author = page.created_by
        tag.double? ? tag.expand : tag.locals.author.name
      end
    end
  end
  
  ['authors:each', 'author'].each do |auth|
    [:name, :email].each do |att|
      desc %{
        Renders the #{att} of the current author
      }
      tag "#{auth}:#{att}" do |tag|
        tag.locals.author.send("#{att}")
      end
    end
  end
  
  ['authors:each', 'author'].each do |auth|
    desc %{
      Renders the bio of the current author
    }
    tag "#{auth}:bio" do |tag|
      author = tag.locals.author
      text = author.bio
      unless author.bio_filter_id.blank?
        text_filter = (author.bio_filter_id + "Filter").constantize.new
        text_filter.filter(text)
      else
        text
      end
    end
    
    desc %{
      Renders the gravatar URL for the current author.
    }
    tag "#{auth}:gravatar_url" do |tag|
      author = tag.locals.author
      size = tag.attr['size']
      format = tag.attr['format']
      rating = tag.attr['rating']
      default = tag.attr['default']
      md5 = Digest::MD5.hexdigest(author.email)
      returning "http://www.gravatar.com/avatar/#{md5}" do |url|
        url << ".#{format.downcase}" if format
        if size || rating || default
          attrs = []
          attrs << "s=#{size}" if size
          attrs << "d=#{default}" if default
          attrs << "r=#{rating.downcase}" if rating
          url << "?#{attrs.join('&')}"
        end
      end
    end
  end
  
  desc %{
    Sets the scope for all Authors
    
    *Usage:*
    <pre><code><r:authors>...</r:authors></code></pre>
  }
  tag 'authors' do |tag|
    tag.expand
  end
  
  desc %{
    Renders its contents for each User in the collection. You may use
    the @limit@ and @offset@ attributes to alter the collection of authors.
    You may select authors by adding one or more to the @login@ attribute 
    and separating them by a comma
    
    *Usage:*
    <pre><code><r:authors:each [limit="10" offset="20" login="sean, john"]>...</r:authors:each></code></pre>
  }
  tag 'authors:each' do |tag|
    attr = tag.attr.symbolize_keys
    options = standard_options(attr)
    if attr[:login]
      login = attr[:login].gsub(' ','')
      logins = login.split(',')
      options[:conditions] = ['login in (?)', logins]
    end
    authors = User.find(:all, options)
    result = []
    tag.locals.authors = authors
    authors.each do |author|
      tag.locals.author = author
      result << tag.expand
    end
    result
  end
  
  desc %{
    Sets the scope for the current author's pages.
  }
  tag "pages" do |tag|
    tag.locals.author = tag.locals.page.created_by unless tag.locals.author
    if tag.locals.author
      tag.locals.pages = tag.locals.author.pages
      tag.expand
    end
  end
  
  desc %{
    Renders the total number of pages by the current author.
  }
  tag "pages:count" do |tag|
    options = children_find_options(tag)
    tag.locals.pages.find(:all, options).size
  end
  
  desc %{
    Renders the contents for each page of the current author.
  }
  tag "pages:each" do |tag|
    attr = tag.attr.symbolize_keys
    options = children_find_options(tag)
    result = []
    url = attr[:url]
    if url
      found = Page.find_by_url(absolute_path_for(tag.locals.page.url, url))
      if page_found?(found)
        found.children.find(:all, options).each do |p|
          tag.locals.page = p
          result << tag.expand
        end
      end
    else
      tag.locals.pages.find(:all, options).each do |p|
        tag.locals.page = p
        result << tag.expand
      end
    end
    result
  end

  desc %{
    Renders the date based on the current page (by default when it was published or created).
    The format attribute uses the same formating codes used by the Ruby @strftime@ function. By
    default it's set to @%A, %B %d, %Y@.  The @for@ attribute selects which date to render.  Valid
    options are @published_at@, @created_at@, @updated_at@, and @now@. @now@ will render the
    current date/time, regardless of the  page.

    *Usage:*

    <pre><code><r:date [format="%A, %B %d, %Y"] [for="published_at"]/></code></pre>
  }
  tag 'date' do |tag|
    page = tag.locals.page
    format = (tag.attr['format'] || '%A, %B %d, %Y')
    time_attr = tag.attr['for']
    date = if time_attr
      case
      when time_attr == 'now'
        Time.now
      when ['published_at', 'created_at', 'updated_at'].include?(time_attr)
        page[time_attr]
      else
        raise TagError, "Invalid value for 'for' attribute."
      end
    else
      page.published_at || page.created_at
    end
    adjust_time(date).strftime(format)
  end

  desc %{
    Renders a link to the page. When used as a single tag it uses the page's title
    for the link name. When used as a double tag the part in between both tags will
    be used as the link text. The link tag passes all attributes over to the HTML
    @a@ tag. This is very useful for passing attributes like the @class@ attribute
    or @id@ attribute. If the @anchor@ attribute is passed to the tag it will
    append a pound sign (<code>#</code>) followed by the value of the attribute to
    the @href@ attribute of the HTML @a@ tag--effectively making an HTML anchor.

    *Usage:*

    <pre><code><r:link [anchor="name"] [other attributes...] /></code></pre>
    
    or
    
    <pre><code><r:link [anchor="name"] [other attributes...]>link text here</r:link></code></pre>
  }
  tag 'link' do |tag|
    options = tag.attr.dup
    anchor = options['anchor'] ? "##{options.delete('anchor')}" : ''
    attributes = options.inject('') { |s, (k, v)| s << %{#{k.downcase}="#{v}" } }.strip
    attributes = " #{attributes}" unless attributes.empty?
    text = tag.double? ? tag.expand : tag.render('title')
    %{<a href="#{tag.render('url')}#{anchor}"#{attributes}>#{text}</a>}
  end

  desc %{
    Renders a trail of breadcrumbs to the current page. The separator attribute
    specifies the HTML fragment that is inserted between each of the breadcrumbs. By
    default it is set to @>@. The boolean nolinks attribute can be specified to render
    breadcrumbs in plain text, without any links (useful when generating title tag).

    *Usage:*

    <pre><code><r:breadcrumbs [separator="separator_string"] [nolinks="true"] /></code></pre>
  }
  tag 'breadcrumbs' do |tag|
    page = tag.locals.page
    breadcrumbs = [page.breadcrumb]
    nolinks = (tag.attr['nolinks'] == 'true')
    page.ancestors.each do |ancestor|
      tag.locals.page = ancestor
      if nolinks
        breadcrumbs.unshift tag.render('breadcrumb')
      else
        breadcrumbs.unshift %{<a href="#{tag.render('url')}">#{tag.render('breadcrumb')}</a>}
      end
    end
    separator = tag.attr['separator'] || ' &gt; '
    breadcrumbs.join(separator)
  end

  desc %{
    Renders the snippet specified in the @name@ attribute within the context of a page.

    *Usage:*

    <pre><code><r:snippet name="snippet_name" /></code></pre>

    When used as a double tag, the part in between both tags may be used within the
    snippet itself, being substituted in place of @<r:yield/>@.

    *Usage:*

    <pre><code><r:snippet name="snippet_name">Lorem ipsum dolor...</r:snippet></code></pre>
  }
  tag 'snippet' do |tag|
    if name = tag.attr['name']
      if snippet = Snippet.find_by_name(name.strip)
        tag.locals.yield = tag.expand if tag.double?
        tag.globals.page.render_snippet(snippet)
      else
        raise TagError.new('snippet not found')
      end
    else
      raise TagError.new("`snippet' tag must contain `name' attribute")
    end
  end

  desc %{
    Used within a snippet as a placeholder for substitution of child content, when
    the snippet is called as a double tag.

    *Usage (within a snippet):*
    
    <pre><code>
    <div id="outer">
      <p>before</p>
      <r:yield/>
      <p>after</p>
    </div>
    </code></pre>

    If the above snippet was named "yielding", you could call it from any Page,
    Layout or Snippet as follows:

    <pre><code><r:snippet name="yielding">Content within</r:snippet></code></pre>

    Which would output the following:

    <pre><code>
    <div id="outer">
      <p>before</p>
      Content within
      <p>after</p>
    </div>
    </code></pre>

    When called in the context of a Page or a Layout, @<r:yield/>@ outputs nothing.
  }
  tag 'yield' do |tag|
    tag.locals.yield
  end

  desc %{
    Inside this tag all page related tags refer to the page found at the @url@ attribute.
    @url@s may be relative or absolute paths.

    *Usage:*

    <pre><code><r:find url="value_to_find">...</r:find></code></pre>
  }
  tag 'find' do |tag|
    url = tag.attr['url']
    raise TagError.new("`find' tag must contain `url' attribute") unless url

    found = Page.find_by_url(absolute_path_for(tag.locals.page.url, url))
    if page_found?(found)
      tag.locals.page = found
      tag.expand
    end
  end

  desc %{
    Randomly renders one of the options specified by the @option@ tags.

    *Usage:*

    <pre><code><r:random>
      <r:option>...</r:option>
      <r:option>...</r:option>
      ...
    <r:random>
    </code></pre>
  }
  tag 'random' do |tag|
    tag.locals.random = []
    tag.expand
    options = tag.locals.random
    option = options[rand(options.size)]
    option if option
  end
  tag 'random:option' do |tag|
    items = tag.locals.random
    items << tag.expand
  end

  desc %{
    Nothing inside a set of comment tags is rendered.

    *Usage:*

    <pre><code><r:comment>...</r:comment></code></pre>
  }
  tag 'comment' do |tag|
  end

  desc %{
    Escapes angle brackets, etc. for rendering in an HTML document.

    *Usage:*

    <pre><code><r:escape_html>...</r:escape_html></code></pre>
  }
  tag "escape_html" do |tag|
    CGI.escapeHTML(tag.expand)
  end

  desc %{
    Outputs the published date using the format mandated by RFC 1123. (Ideal for RSS feeds.)

    *Usage:*

    <pre><code><r:rfc1123_date /></code></pre>
  }
  tag "rfc1123_date" do |tag|
    page = tag.locals.page
    if date = page.published_at || page.created_at
      CGI.rfc1123_date(date.to_time)
    end
  end

  desc %{
    Renders a list of links specified in the @urls@ attribute according to three
    states:

    * @normal@ specifies the normal state for the link
    * @here@ specifies the state of the link when the url matches the current
       page's URL
    * @selected@ specifies the state of the link when the current page matches
       is a child of the specified url

    The @between@ tag specifies what should be inserted in between each of the links.

    *Usage:*

    <pre><code><r:navigation urls="[Title: url | Title: url | ...]">
      <r:normal><a href="<r:url />"><r:title /></a></r:normal>
      <r:here><strong><r:title /></strong></r:here>
      <r:selected><strong><a href="<r:url />"><r:title /></a></strong></r:selected>
      <r:between> | </r:between>
    </r:navigation>
    </code></pre>
  }
  tag 'navigation' do |tag|
    hash = tag.locals.navigation = {}
    tag.expand
    raise TagError.new("`navigation' tag must include a `normal' tag") unless hash.has_key? :normal
    result = []
    pairs = tag.attr['urls'].to_s.split('|').map do |pair|
      parts = pair.split(':')
      value = parts.pop
      key = parts.join(':')
      [key.strip, value.strip]
    end
    pairs.each do |title, url|
      compare_url = remove_trailing_slash(url)
      page_url = remove_trailing_slash(self.url)
      hash[:title] = title
      hash[:url] = url
      case page_url
      when compare_url
        result << (hash[:here] || hash[:selected] || hash[:normal]).call
      when Regexp.compile( '^' + Regexp.quote(url))
        result << (hash[:selected] || hash[:normal]).call
      else
        result << hash[:normal].call
      end
    end
    between = hash.has_key?(:between) ? hash[:between].call : ' '
    result.reject { |i| i.blank? }.join(between)
  end
  [:normal, :here, :selected, :between].each do |symbol|
    tag "navigation:#{symbol}" do |tag|
      hash = tag.locals.navigation
      hash[symbol] = tag.block
    end
  end
  [:title, :url].each do |symbol|
    tag "navigation:#{symbol}" do |tag|
      hash = tag.locals.navigation
      hash[symbol]
    end
  end
  
    desc %{
    Set's the scope for a page's siblings. 
    
    The order in which siblings are sorted can be manipulated using all the same attributes
    as the @<r:children:each/>@ tag. If no attributes are supplied, the siblings will
    have order = "published_at ASC". The @by@ attribute allows you to order by any page 
    properties stored in the database, the most likely of these to be useful are 
    @published_at@ and @title@.
    
    Values set in the @<r:siblings/>@ tag will be inherited by tags nested within, 
    but may also be overridden in the child tags.
      
    *Usage:*
    <pre><code><r:siblings [by="published_at|title"] [order="asc|desc"] [status="published|all"]/>
      <r:next><r:link/></r:next>
      <r:previous><r:link/></r:previous>
    </r:siblings></code></pre>
  }
  tag 'siblings' do |tag|
    tag.locals.filter_attributes = tag.attr || {}
    tag.expand
  end
    
    desc %{
      Loops through each sibling and outputs the contents
    }
    tag 'siblings:each' do |tag|
      result = []
      inherit_filter_attributes(tag)
      tag.locals.siblings = tag.locals.page.parent.children.find(:all, siblings_find_options(tag))
      tag.locals.siblings.each do |sib|
        tag.locals.page = sib
        result << tag.expand
      end
      result
    end
    
    desc %{
      Only renders the contents of this tag if the current page has any published siblings.
    }
    tag 'if_siblings' do |tag|
      if parent = tag.locals.page.parent
        if parent.children.find(:all, siblings_find_options(tag)).size > 0
          tag.expand
        end
      end
    end
    
    desc %{
      Only renders the contents of this tag if the current page has no published siblings.
    }
    tag 'unless_siblings' do |tag|
      if !tag.locals.page.parent or tag.locals.page.parent.children.find(:all, siblings_find_options(tag)).size == 0
        tag.expand
      end
    end
    
    desc %{
      Only render the contents of this tag if the current page has a sibling *after* it, when sorted according to the @order@ and @by@ options. 
      
      See @<siblings/>@ for a more detailed description of the sorting options.
    }
    tag 'siblings:if_next' do |tag|
      inherit_filter_attributes(tag)
      tag.expand if find_next_sibling(tag)
    end
    
    desc %{
      Only render the contents of this tag if the current page has a sibling *before* it, when sorted according to the @order@ and @by@ options. 
      
      See @<siblings/>@ for a more detailed description of the sorting options.
    }
    tag 'siblings:if_previous' do |tag|
      inherit_filter_attributes(tag)
      tag.expand if find_previous_sibling(tag)
    end
    
    desc %{
      Only render the contents of this tag if the current page is the last of its siblings, when sorted according to the @order@ and @by@ options. 
      
      See @<siblings/>@ for a more detailed description of the sorting options.
    }
    tag 'siblings:unless_next' do |tag|
      inherit_filter_attributes(tag)
      tag.expand unless find_next_sibling(tag)
    end
    
    desc %{
      Only render the contents of this tag if the current page is the first of its siblings, when sorted according to the @order@ and @by@ options. 
      
      See @<siblings/>@ for a more detailed description of the sorting options.
    }
    tag 'siblings:unless_previous' do |tag|
      inherit_filter_attributes(tag)
      tag.expand unless find_previous_sibling(tag)
    end
    
    desc %{
      All Radiant tags within a @<r:siblings:next/>@ block are interpreted in the context
      of the next sibling page. 
      
      See @<siblings/>@ for a more detailed description of the sorting options.
      
      *Usage:*
      <pre><code><r:siblings:next [by="published_at|title"] [order="asc|desc"] [status="published|all"]/>...</r:siblings:next></code></pre>
    }
    tag 'siblings:next' do |tag|
      inherit_filter_attributes(tag)
      tag.expand if tag.locals.page = find_next_sibling(tag)
    end
    
    desc %{
      Displays its contents for each of the following pages according to the given
      attributes. See @<siblings>@ for details about the attributes.
    }
    tag 'siblings:each_before' do |tag|
      inherit_filter_attributes(tag)
      result = []
      tag.locals.siblings = find_siblings_before(tag)
      tag.locals.siblings.each do |sib|
        tag.locals.page = sib
        result << tag.expand
      end
      result
    end
    
    desc %{
      All Radiant tags within a @<r:siblings:previous/>@ block are interpreted in the context
      of the previous sibling page, when sorted according to the @order@ and @by@ options.
      
      See @<siblings/>@ for a more detailed description of the sorting options.
      
      *Usage:*
      <pre><code><r:siblings:previous [by="published_at|title"] [order="asc|desc"] 
      [status="published|all"]/>...</r:siblings:previous></code></pre>
    }
    tag 'siblings:previous' do |tag|
      inherit_filter_attributes(tag)
      tag.expand if tag.locals.page = find_previous_sibling(tag)
    end
    
    desc %{
      Displays its contents for each of the following pages according to the given
      attributes. See @<siblings>@ for details about the attributes.
    }
    tag 'siblings:each_after' do |tag|
      inherit_filter_attributes(tag)
      result = []
      tag.locals.siblings = find_siblings_after(tag)
      tag.locals.siblings.each do |sib|
        tag.locals.page = sib
        result << tag.expand
      end
      result
    end

  desc %{
    Renders the containing elements only if Radiant in is development mode.

    *Usage:*

    <pre><code><r:if_dev>...</r:if_dev></code></pre>
  }
  tag 'if_dev' do |tag|
    tag.expand if dev?(tag.globals.page.request)
  end

  desc %{
    The opposite of the @if_dev@ tag.

    *Usage:*

    <pre><code><r:unless_dev>...</r:unless_dev></code></pre>
  }
  tag 'unless_dev' do |tag|
    tag.expand unless dev?(tag.globals.page.request)
  end

  desc %{
    Prints the page's status as a string.  Optional attribute 'downcase'
    will cause the status to be all lowercase.

    *Usage:*

    <pre><code><r:status [downcase='true'] /></code></pre>
  }
  tag 'status' do |tag|
    status = tag.globals.page.status.name
    return status.downcase if tag.attr['downcase']
    status
  end

  desc %{
    The namespace for 'meta' attributes.  If used as a singleton tag, both the description
    and keywords fields will be output as &lt;meta /&gt; tags unless the attribute 'tag' is set to 'false'.

    *Usage*:

    <pre><code> <r:meta [tag="false"] />
     <r:meta>
       <r:description [tag="false"] />
       <r:keywords [tag="false"] />
     </r:meta>
    </code></pre>
  }
  tag 'meta' do |tag|
    if tag.double?
      tag.expand
    else
      tag.render('description', tag.attr) +
      tag.render('keywords', tag.attr)
    end
  end

  desc %{
    Emits the page description field in a meta tag, unless attribute
    'tag' is set to 'false'.

    *Usage*:

    <pre><code> <r:meta:description [tag="false"] /> </code></pre>
  }
  tag 'meta:description' do |tag|
    show_tag = tag.attr['tag'] != 'false' || false
    description = CGI.escapeHTML(tag.locals.page.description)
    if show_tag
      "<meta name=\"description\" content=\"#{description}\" />"
    else
      description
    end
  end

  desc %{
    Emits the page keywords field in a meta tag, unless attribute
    'tag' is set to 'false'.

    *Usage*:

    <pre><code> <r:meta:keywords [tag="false"] /> </code></pre>
  }
  tag 'meta:keywords' do |tag|
    show_tag = tag.attr['tag'] != 'false' || false
    keywords = CGI.escapeHTML(tag.locals.page.keywords)
    if show_tag
      "<meta name=\"keywords\" content=\"#{keywords}\" />"
    else
      keywords
    end
  end

  private

    def children_find_options(tag)
      attr = tag.attr.symbolize_keys

      options = standard_options(attr)

      by = (attr[:by] || 'published_at').strip
      order = (attr[:order] || 'asc').strip
      order_string = ''
      if self.attributes.keys.include?(by)
        order_string << by
      else
        raise TagError.new("`by' attribute of `each' tag must be set to a valid field name")
      end
      if order =~ /^(asc|desc)$/i
        order_string << " #{$1.upcase}"
      else
        raise TagError.new(%{`order' attribute of `each' tag must be set to either "asc" or "desc"})
      end
      options[:order] = order_string

      status = (attr[:status] || ( dev?(tag.globals.page.request) ? 'all' : 'published')).downcase
      unless status == 'all'
        stat = Status[status]
        unless stat.nil?
          options[:conditions] = ["(virtual = ?) and (status_id = ?)", false, stat.id]
        else
          raise TagError.new(%{`status' attribute of `each' tag must be set to a valid status})
        end
      else
        options[:conditions] = ["virtual = ?", false]
      end
      options
    end
    
    def standard_options(attr)
      options = {}
      [:limit, :offset].each do |symbol|
        if number = attr[symbol]
          if number =~ /^\d{1,4}$/
            options[symbol] = number.to_i
          else
            raise TagError.new("`#{symbol}' attribute of `each' tag must be a positive number between 1 and 4 digits")
          end
        end
      end
      options
    end

    def remove_trailing_slash(string)
      (string =~ %r{^(.*?)/$}) ? $1 : string
    end

    def tag_part_name(tag)
      tag.attr['part'] || 'body'
    end

    def build_regexp_for(tag, attribute_name)
      ignore_case = tag.attr.has_key?('ignore_case') && tag.attr['ignore_case']=='false' ? nil : true
      begin
        regexp = Regexp.new(tag.attr['matches'], ignore_case)
      rescue RegexpError => e
        raise TagError.new("Malformed regular expression in `#{attribute_name}' argument of `#{tag.name}' tag: #{e.message}")
      end
      regexp
    end

    def relative_url_for(url, request)
      File.join(request.relative_url_root, url)
    end

    def absolute_path_for(base_path, new_path)
      if new_path.first == '/'
        new_path
      else
        File.expand_path(File.join(base_path, new_path))
      end
    end

    def page_found?(page)
      page && !(FileNotFoundPage === page)
    end

    def boolean_attr_or_error(tag, attribute_name, default)
      attribute = attr_or_error(tag, :attribute_name => attribute_name, :default => default.to_s, :values => 'true, false')
      (attribute.to_s.downcase == 'true') ? true : false
    end

    def attr_or_error(tag, options = {})
      attribute_name = options[:attribute_name].to_s
      default = options[:default]
      values = options[:values].split(',').map!(&:strip)

      attribute = (tag.attr[attribute_name] || default).to_s
      raise TagError.new(%{'#{attribute_name}' attribute of #{tag} tag must be one of: #{values.join(',')}}) unless values.include?(attribute)
      return attribute
    end

    def dev?(request)
      dev_host = Radiant::Config['dev.host']
      request && ((dev_host && dev_host == request.host) || request.host =~ /^dev\./)
    end
    
    
    
    def inherit_filter_attributes(tag)
      tag.attr ||= {}
      tag.attr.reverse_merge!(tag.locals.filter_attributes)
    end
    
    def find_next_sibling(tag)
      if tag.locals.page.parent
        tag.attr['adjacent'] = 'next'
        tag.locals.page.parent.children.find(:first, adjacent_siblings_find_options(tag))
      end
    end
    
    def find_siblings_before(tag)
      if tag.locals.page.parent
        tag.attr['adjacent'] = 'previous'
        tag.locals.page.parent.children.find(:all, adjacent_siblings_find_options(tag)).reverse!
      end
    end
    
    def find_previous_sibling(tag)
      if tag.locals.page.parent
        tag.attr['adjacent'] = 'previous'
        sorted = tag.locals.page.parent.children.find(:all, adjacent_siblings_find_options(tag))
        sorted.last unless sorted.blank?
      end
    end
    
    def find_siblings_after(tag)
      if tag.locals.page.parent
        tag.attr['adjacent'] = 'next'
        tag.locals.page.parent.children.find(:all, adjacent_siblings_find_options(tag))
      end
    end
    
    def adjacent_siblings_find_options(tag)
      options = siblings_find_options(tag)
      adjacent_condition = attr_or_error(tag, :attribute_name => 'adjacent', :default => 'next', :values => 'next, previous')
      attribute_sort = (tag.attr['by'] || 'published_at').strip
      attribute_order = attr_or_error(tag, :attribute_name => 'order', :default => 'asc', :values => 'desc, asc')
      
      find_less_than    = " and (#{attribute_sort} < ?)"
      find_greater_than = " and (#{attribute_sort} > ?)"
      
      if attribute_order == "asc"
        adjacent_find_condition = (adjacent_condition == 'previous' ? find_less_than : find_greater_than)
      else
        adjacent_find_condition = (adjacent_condition == 'previous' ? find_greater_than : find_less_than)
      end
      
      options[:conditions].first << adjacent_find_condition
      options[:conditions] << tag.locals.page.send(attribute_sort)
      
      options
    end
    
    def siblings_find_options(tag)
      options = children_find_options(tag)
      options[:conditions].first << ' and (id != ?)'
      options[:conditions] << tag.locals.page.id
      options
    end
end
