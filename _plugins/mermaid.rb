# Replaces the unmaintained jekyll-mermaid gem (2014).
# Renders {% mermaid %}...{% endmermaid %} as a div; the CDN script is loaded once
# from _includes/footer/custom.html when a page contains diagrams.
module Jekyll
  class MermaidBlock < Liquid::Block
    def render(context)
      "<div class=\"mermaid\">#{super}</div>"
    end
  end
end

Liquid::Template.register_tag("mermaid", Jekyll::MermaidBlock)
