require 'spec_helper'

describe "homesick" do
  let(:home) { create_construct }
  after { home.destroy! }

  let(:castles) { home.directory(".homesick/repos") }

  let(:homesick) { Homesick.new }

  before { homesick.stub!(:repos_dir).and_return(castles) }

  describe "clone" do
    context "of a file" do
      it "should symlink existing directories" do
        somewhere = create_construct
        local_repo = somewhere.directory('wtf')

        homesick.clone local_repo

        castles.join("wtf").readlink.should == local_repo
      end

      context "when it exists in a repo directory" do
        before do
          existing_castle = given_castle("existing_castle")
          @existing_dir = existing_castle.parent
        end

        it "should not symlink" do
          homesick.should_not_receive(:git_clone)

          homesick.clone @existing_dir.to_s rescue nil
        end

        it "should raise an error" do
          expect { homesick.clone @existing_dir.to_s }.to raise_error(/already cloned/i)
        end
      end
    end

    it "should clone git repo like git://host/path/to.git" do
      homesick.should_receive(:git_clone).with('git://github.com/technicalpickles/pickled-vim.git')

      homesick.clone "git://github.com/technicalpickles/pickled-vim.git"
    end

    it "should clone git repo like git@host:path/to.git" do
      homesick.should_receive(:git_clone).with('git@github.com:technicalpickles/pickled-vim.git')

      homesick.clone 'git@github.com:technicalpickles/pickled-vim.git'
    end

    it "should clone git repo like http://host/path/to.git" do
      homesick.should_receive(:git_clone).with('http://github.com/technicalpickles/pickled-vim.git')

      homesick.clone 'http://github.com/technicalpickles/pickled-vim.git'
    end

    it "should clone git repo like http://host/path/to" do
      homesick.should_receive(:git_clone).with('http://github.com/technicalpickles/pickled-vim')

      homesick.clone 'http://github.com/technicalpickles/pickled-vim'
    end

    it "should clone git repo like host-alias:repos.git" do
      homesick.should_receive(:git_clone).with('gitolite:pickled-vim.git')

      homesick.clone 'gitolite:pickled-vim.git'
    end

    it "should not try to clone a malformed uri like malformed" do
      homesick.should_not_receive(:git_clone)

      homesick.clone 'malformed' rescue nil
    end

    it "should throw an exception when trying to clone a malformed uri like malformed" do
      expect { homesick.clone 'malformed' }.to raise_error
    end

    it "should clone a github repo" do
      homesick.should_receive(:git_clone).with('git://github.com/wfarr/dotfiles.git', :destination => Pathname.new('wfarr/dotfiles'))

      homesick.clone "wfarr/dotfiles"
    end
  end

  describe "symlink" do
    let(:castle) { given_castle("glencairn") }

    it "links dotfiles from a castle to the home folder" do
      dotfile = castle.file(".some_dotfile")

      homesick.symlink("glencairn")

      home.join(".some_dotfile").readlink.should == dotfile
    end

    it "links non-dotfiles from a castle to the home folder" do
      dotfile = castle.file("bin")

      homesick.symlink("glencairn")

      home.join("bin").readlink.should == dotfile
    end

    context "when forced" do
      let(:homesick) { Homesick.new [], :force => true }

      it "can override symlinks to directories" do
        somewhere_else = create_construct
        existing_dotdir_link = home.join(".vim")
        FileUtils.ln_s somewhere_else, existing_dotdir_link

        dotdir = castle.directory(".vim")

        homesick.symlink("glencairn")

        existing_dotdir_link.readlink.should == dotdir
      end
    end

    describe 'manifest' do

      it 'should symlink and merge nested files when their parents are listed' do

        manifest = Pathname.new(castle.parent.join('.manifest'))
        relative_path = Pathname.new('some/nested/file.txt')
        some_nested_file = castle.file(relative_path)

        File.open(manifest, 'w') do |f|
          f.puts relative_path.parent
        end

        homesick.symlink('glencairn')

        home.join(relative_path).readlink.should == some_nested_file
      end

      it 'should symlink and merge nested directories when their parents are listed' do

        manifest = Pathname.new(castle.parent.join('.manifest'))
        relative_path = Pathname.new('some/nested/dir')
        some_nested_dir = castle.directory(relative_path)

        File.open(manifest, 'w') do |f|
          f.puts relative_path.parent
        end

        homesick.symlink('glencairn')

        home.join(relative_path).readlink.should == some_nested_dir
      end

      context 'the parent and descendant are both listed in the manifest' do

        it 'does not symlink the dir containing the other listed file' do

          manifest = Pathname.new(castle.parent.join('.manifest'))

          relative_path = Pathname.new('some/nested/dir')
          deeper_rel_path = Pathname.new(relative_path.join('deeper/inside'))

          deeper_nested_inside = castle.file(deeper_rel_path)

          File.open(manifest, 'w') do |f|
            f.puts relative_path.parent
            f.puts deeper_rel_path.parent
          end

          homesick.symlink('glencairn')

          home.join(relative_path).symlink?.should == false
          home.join(deeper_rel_path).readlink.should == deeper_nested_inside
        end
      end
    end
  end

  describe "list" do
    it "should say each castle in the castle directory" do
      given_castle('zomg')
      given_castle('zomg', 'wtf/zomg')

      homesick.should_receive(:say_status).with("zomg", "git://github.com/technicalpickles/zomg.git", :cyan)
      homesick.should_receive(:say_status).with("wtf/zomg", "git://github.com/technicalpickles/zomg.git", :cyan)

      homesick.list
    end
  end

  describe "pull" do

    xit "needs testing"

    describe "--all" do
      xit "needs testing"
    end

  end

  describe "commit" do

    xit "needs testing"

  end

  describe "push" do

    xit "needs testing"

  end

  describe "track" do
    it "should move the tracked file into the castle" do
      castle = given_castle('castle_repo')

      some_rc_file = home.file '.some_rc_file'

      homesick.track(some_rc_file.to_s, 'castle_repo')

      tracked_file = castle.join(".some_rc_file")
      tracked_file.should exist

      some_rc_file.readlink.should == tracked_file
    end

    it 'should track a file in nested folder structure' do
      castle = given_castle('castle_repo')

      some_nested_file = home.file('some/nested/file.txt')
      homesick.track(some_nested_file.to_s, 'castle_repo')

      tracked_file = castle.join('some/nested/file.txt')
      tracked_file.should exist
      some_nested_file.readlink.should == tracked_file
    end

    it 'should track a nested directory' do
      castle = given_castle('castle_repo')

      some_nested_dir = home.directory('some/nested/directory/')
      homesick.track(some_nested_dir.to_s, 'castle_repo')

      tracked_file = castle.join('some/nested/directory/')
      tracked_file.should exist
      File.realdirpath(some_nested_dir).should == File.realdirpath(tracked_file)
    end

    describe "manifest" do

      it 'should add the nested files parent to the manifest' do
        castle = given_castle('castle_repo')

        some_nested_file = home.file('some/nested/file.txt')
        homesick.track(some_nested_file.to_s, 'castle_repo')

        manifest = Pathname.new(castle.parent.join('.manifest'))
        File.open(manifest, 'r') do |f|
          f.readline.should == "some/nested\n"
        end
      end

      it 'should NOT add anything if the files parent is already listed' do
        castle = given_castle('castle_repo')

        some_nested_file = home.file('some/nested/file.txt')
        other_nested_file = home.file('some/nested/other.txt')
        homesick.track(some_nested_file.to_s, 'castle_repo')
        homesick.track(other_nested_file.to_s, 'castle_repo')

        manifest = Pathname.new(castle.parent.join('.manifest'))
        File.open(manifest, 'r') do |f|
          f.readlines.size.should == 1
        end
      end

      it 'should remove the parent of a tracked file from the manifest if the parent itself is tracked' do
        castle = given_castle('castle_repo')

        some_nested_file = home.file('some/nested/file.txt')
        nested_parent = home.directory('some/nested/')
        homesick.track(some_nested_file.to_s, 'castle_repo')
        homesick.track(nested_parent.to_s, 'castle_repo')

        manifest = Pathname.new(castle.parent.join('.manifest'))
        File.open(manifest, 'r') do |f|
          f.each_line { |line| line.should_not == "some/nested\n" }
        end
      end
    end
  end
end
