import logging, os, sys
from argparse import ArgumentParser

from . import Config, ImageConfigs, GitRunner, PodmanRunner, write_config, load_config

class ConfigCLI:
    ACTION = "config"
    HELP = "Print or save config file"

    @staticmethod
    def execute(base_dir, args):
        write_config(sys.stdout)
        sys.stdout.write('\n')
        if args.save is not None:
            path = args.save if os.path.isabs(args.save) else os.path.join(base_dir, args.save)
            if not path.endswith(".json"):
                print("Invalid config file: %s, must be '.json'" % args.save)
                sys.exit(1)
            with open(path, 'w') as w:
                write_config(w)
                print("Saved to file: %s" % path)

    @staticmethod
    def bind(parser):
        parser.add_argument("-s", "--save")

class ImageCLI:
    ACTION = "fetch"
    HELP = "Fetch remote build containers"

    @staticmethod
    def execute(base_dir, args):
        podman = PodmanRunner(
            base_dir,
            dry_run=args.dry_run
        )
        podman.login()
        podman.fetch_images(
            images = args.image,
            force=args.force_download
        )

    @staticmethod
    def bind(parser):
        parser.add_argument("-f", "--force-download", action="store_true")
        parser.add_argument("-i", "--image", action="append", default=[], help="The image to fetch, all by default. Possible values: %s" % ", ".join(PodmanRunner.get_images()))


class GitCLI:
    ACTION = "checkout"
    HELP = "git checkout, version check, tar"

    @staticmethod
    def execute(base_dir, args):
        git = GitRunner(base_dir, dry_run=args.dry_run)
        if not args.skip_checkout:
            git.checkout(args.treeish)
        if not args.skip_check:
            git.check_version(args.godot_version)
        if not args.skip_tar:
            git.tgz(args.godot_version)

    @staticmethod
    def bind(parser):
        parser.add_argument("treeish", help="git treeish, possibly a git ref, or commit hash.", default="origin/master")
        parser.add_argument("godot_version", help="godot version (e.g. 3.1-alpha5)")
        parser.add_argument("-c", "--skip-checkout", action="store_true")
        parser.add_argument("-t", "--skip-tar", action="store_true")
        parser.add_argument("--skip-check", action="store_true")


class RunCLI:
    ACTION = "run"
    HELP = "Run the desired containers"

    CONTAINERS = [cls.__name__.replace("Config", "") for cls in ImageConfigs]

    @staticmethod
    def execute(base_dir, args):
        podman = PodmanRunner(base_dir, dry_run=args.dry_run)
        build_mono = args.build == "all" or args.build == "mono"
        build_classical = args.build == "all" or args.build == "classical"
        if len(args.container) == 0:
            args.container = RunCLI.CONTAINERS
        to_build = [ImageConfigs[RunCLI.CONTAINERS.index(c)] for c in args.container]
        for b in to_build:
            podman.podrun(b, classical=build_classical, mono=build_mono, local=not args.remote, interactive=args.interactive)

    def bind(parser):
        parser.add_argument("-b", "--build", choices=["all", "classical", "mono"], default="all")
        parser.add_argument("-k", "--container", action="append", default=[], help="The containers to build, one of %s" % RunCLI.CONTAINERS)
        parser.add_argument("-r", "--remote", help="Run with remote containers", action="store_true")
        parser.add_argument("-i", "--interactive", action="store_true", help="Enter an interactive shell inside the container instead of running the default command")


class ReleaseCLI:
    ACTION = "release"
    HELP = "Make a full release cycle, git checkout, reset, version check, tar, build all"

    @staticmethod
    def execute(base_dir, args):
        git = GitRunner(base_dir, dry_run=args.dry_run)
        podman = PodmanRunner(base_dir, dry_run=args.dry_run)
        build_mono = args.build == "all" or args.build == "mono"
        build_classical = args.build == "all" or args.build == "classical"
        if not args.localhost and not args.skip_download:
            podman.login()
            podman.fetch_images(
                force=args.force_download
            )
        if not args.skip_git:
            git.checkout(args.git)
            git.check_version(args.godot_version)
            git.tgz(args.godot_version)

        for b in ImageConfigs:
            podman.podrun(b, classical=build_classical, mono=build_mono, local=args.localhost)

    @staticmethod
    def bind(parser):
        parser.add_argument("godot_version", help="godot version (e.g. 3.1-alpha5)")
        parser.add_argument("-b", "--build", choices=["all", "classical", "mono"], default="all")
        parser.add_argument("-s", "--skip-download", action="store_true")
        parser.add_argument("-c", "--skip-git", action="store_true")
        parser.add_argument("-g", "--git", help="git treeish, possibly a git ref, or commit hash.", default="origin/master")
        parser.add_argument("-f", "--force-download", action="store_true")
        parser.add_argument("-l", "--localhost", action="store_true")


class CLI:
    OPTS = [(v, getattr(Config, v)) for v in dir(Config) if not v.startswith("_")]

    def add_command(self, cli):
        parser = self.subparsers.add_parser(cli.ACTION, help=cli.HELP)
        parser.add_argument("-n", "--dry-run", action="store_true")
        parser.set_defaults(action_func=cli.execute)
        cli.bind(parser)

    def __init__(self, base_dir):
        self.base_dir = base_dir
        self.parser = ArgumentParser()
        for k,v in CLI.OPTS:
            self.parser.add_argument("--%s" % k)
        self.parser.add_argument("-c", "--config", help="Configuration override")
        self.subparsers = self.parser.add_subparsers(dest="action", help="The requested action", required=True)
        self.add_command(ConfigCLI)
        self.add_command(GitCLI)
        self.add_command(ImageCLI)
        self.add_command(RunCLI)
        self.add_command(ReleaseCLI)

    def execute(self):
        args = self.parser.parse_args()
        if args.config is not None:
            path = args.config if os.path.isabs(args.config) else os.path.join(self.base_dir, args.config)
            if not os.path.isfile(path):
                print("Invalid config file: %s" % path)
                sys.exit(1)
            load_config(path)
        for k,v in CLI.OPTS:
            override = getattr(args, k)
            if override is not None:
                setattr(Config, k, override)
        args.action_func(self.base_dir, args)


def main(loglevel=logging.DEBUG):
    logging.basicConfig(level=loglevel)
    CLI(os.getcwd()).execute()

if __name__ == "__main__":
    main()
