FROM ruby:2.7-bullseye AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install main dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential  \
  netcat \
  curl \
  libmariadbclient-dev-compat \
  nano \
  nodejs

# RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/ruby

# Configure 'postal' to work everywhere (when the binary exists
# later in this process)
ENV PATH="/opt/postal/app/bin:${PATH}"

# Copy and apply openssl.cnf.patch
COPY ./docker/openssl.cnf.patch /etc/ssl/openssl.cnf.patch
RUN patch /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.patch

# Setup an application
RUN useradd -r -d /opt/postal -m -s /bin/bash -u 999 postal
USER postal
RUN mkdir -p /opt/postal/app /opt/postal/config
WORKDIR /opt/postal/app

# Install bundler
RUN gem install bundler -v 2.3.26 --no-doc

# Install the latest and active gem dependencies and re-run
# the appropriate commands to handle installs.
COPY Gemfile Gemfile.lock ./
RUN bundle install -j 4

# Copy the application (and set permissions)
COPY ./docker/wait-for.sh /docker-entrypoint.sh
COPY --chown=postal . .

# Export the version
ARG VERSION=unspecified
RUN echo $VERSION > VERSION

# Set the path to the config
ENV POSTAL_CONFIG_ROOT=/config

# Set the CMD
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["postal"]

# ci target - use --target=ci to skip asset compilation
FROM base AS ci

# prod target - default if no --target option is given
FROM base AS prod

RUN POSTAL_SKIP_CONFIG_CHECK=1 RAILS_GROUPS=assets bundle exec rake assets:precompile
RUN touch /opt/postal/app/public/assets/.prebuilt
